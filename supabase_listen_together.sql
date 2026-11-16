-- ============================================================================
-- SUPABASE MIGRATION: Listen Together Rooms (Synchronized Group Playback)
-- ============================================================================
-- Run this script in your Supabase SQL Editor.
-- It creates all required tables, triggers, RPC functions, and Row Level Security (RLS) policies.

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABLES

-- Table: rooms
CREATE TABLE IF NOT EXISTS public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at TIMESTAMPTZ
);

-- Table: room_members
CREATE TABLE IF NOT EXISTS public.room_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'controller', 'listener')),
    display_name TEXT NOT NULL DEFAULT 'Music Lover',
    avatar_url TEXT DEFAULT '',
    is_ready BOOLEAN NOT NULL DEFAULT false,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at TIMESTAMPTZ,
    CONSTRAINT uq_room_member UNIQUE (room_id, user_id)
);

-- Table: room_playback_state (Exactly one row per room - sync source of truth)
CREATE TABLE IF NOT EXISTS public.room_playback_state (
    room_id UUID PRIMARY KEY REFERENCES public.rooms(id) ON DELETE CASCADE,
    current_track_id TEXT,
    current_track_metadata JSONB,
    is_playing BOOLEAN NOT NULL DEFAULT false,
    position_ms INTEGER NOT NULL DEFAULT 0,
    scheduled_start_server_ms BIGINT DEFAULT 0,
    updated_at_server TIMESTAMPTZ NOT NULL DEFAULT now(),
    version INTEGER NOT NULL DEFAULT 1,
    updated_by UUID REFERENCES auth.users(id)
);

-- Table: room_queue
CREATE TABLE IF NOT EXISTS public.room_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    track_id TEXT NOT NULL,
    track_metadata JSONB NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    added_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    added_by_name TEXT NOT NULL DEFAULT 'Listener',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_rooms_code ON public.rooms(code) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_room_members_room ON public.room_members(room_id) WHERE left_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_room_members_user ON public.room_members(user_id) WHERE left_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_room_queue_room ON public.room_queue(room_id, position ASC);

-- 4. REALTIME PUBLICATION
-- Enable Supabase Realtime on all 4 tables so changes push to clients in milliseconds
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.room_members;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.room_playback_state;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.room_queue;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 5. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_playback_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_queue ENABLE ROW LEVEL SECURITY;

-- Helper security functions
CREATE OR REPLACE FUNCTION public.is_room_active_member(p_room_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.room_members
        WHERE room_id = p_room_id
          AND user_id = p_user_id
          AND left_at IS NULL
    );
$$;

CREATE OR REPLACE FUNCTION public.get_room_member_role(p_room_id UUID, p_user_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT role FROM public.room_members
    WHERE room_id = p_room_id
      AND user_id = p_user_id
      AND left_at IS NULL
    LIMIT 1;
$$;

-- RLS: rooms
CREATE POLICY "Active members can view room"
    ON public.rooms FOR SELECT
    USING (public.is_room_active_member(id, auth.uid()) OR admin_id = auth.uid());

CREATE POLICY "Admin can update room"
    ON public.rooms FOR UPDATE
    USING (admin_id = auth.uid());

-- RLS: room_members
CREATE POLICY "Members can view room members"
    ON public.room_members FOR SELECT
    USING (public.is_room_active_member(room_id, auth.uid()));

CREATE POLICY "Users can update their own membership or admin can manage"
    ON public.room_members FOR UPDATE
    USING (
        user_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.rooms WHERE id = room_members.room_id AND admin_id = auth.uid())
    );

-- RLS: room_playback_state
CREATE POLICY "Members can view playback state"
    ON public.room_playback_state FOR SELECT
    USING (public.is_room_active_member(room_id, auth.uid()));

CREATE POLICY "Admin and controllers can update playback state"
    ON public.room_playback_state FOR UPDATE
    USING (
        public.get_room_member_role(room_id, auth.uid()) IN ('admin', 'controller')
    );

-- RLS: room_queue
CREATE POLICY "Members can view queue"
    ON public.room_queue FOR SELECT
    USING (public.is_room_active_member(room_id, auth.uid()));

CREATE POLICY "Admin and controllers can insert queue items"
    ON public.room_queue FOR INSERT
    WITH CHECK (
        public.get_room_member_role(room_id, auth.uid()) IN ('admin', 'controller')
    );

CREATE POLICY "Admin and controllers can update queue items"
    ON public.room_queue FOR UPDATE
    USING (
        public.get_room_member_role(room_id, auth.uid()) IN ('admin', 'controller')
    );

CREATE POLICY "Admin and controllers can delete queue items"
    ON public.room_queue FOR DELETE
    USING (
        public.get_room_member_role(room_id, auth.uid()) IN ('admin', 'controller')
    );


-- 6. RPC SERVER-SIDE FUNCTIONS (BUSINESS LOGIC & CODE GENERATION)

-- Utility: Returns exact server epoch time in milliseconds for clock offset estimation
CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT;
$$;

-- Utility: Generate unique 6-character room code (avoiding O, 0, I, 1)
CREATE OR REPLACE FUNCTION public.generate_unique_room_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    chars CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    result TEXT := '';
    i INTEGER;
    is_unique BOOLEAN := false;
BEGIN
    WHILE NOT is_unique LOOP
        result := '';
        FOR i IN 1..6 LOOP
            result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
        END LOOP;
        IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE code = result AND is_active = true) THEN
            is_unique := true;
        END IF;
    END LOOP;
    RETURN result;
END;
$$;

-- RPC: create_room
CREATE OR REPLACE FUNCTION public.create_room(
    p_display_name TEXT DEFAULT 'Host',
    p_avatar_url TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_code TEXT;
    v_room_id UUID;
    v_room_record RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to create a room.';
    END IF;

    -- Deactivate any existing active rooms hosted by this user
    UPDATE public.rooms
    SET is_active = false, ended_at = now()
    WHERE admin_id = v_user_id AND is_active = true;

    -- Generate unique 6-character code
    v_code := public.generate_unique_room_code();

    -- Create room
    INSERT INTO public.rooms (code, admin_id, is_active, created_at)
    VALUES (v_code, v_user_id, true, now())
    RETURNING id INTO v_room_id;

    -- Insert admin as first room member
    INSERT INTO public.room_members (room_id, user_id, role, display_name, avatar_url, is_ready, joined_at)
    VALUES (v_room_id, v_user_id, 'admin', COALESCE(NULLIF(p_display_name, ''), 'Host'), p_avatar_url, true, now());

    -- Initialize room playback state
    INSERT INTO public.room_playback_state (
        room_id,
        current_track_id,
        current_track_metadata,
        is_playing,
        position_ms,
        scheduled_start_server_ms,
        updated_at_server,
        version,
        updated_by
    ) VALUES (
        v_room_id,
        NULL,
        NULL,
        false,
        0,
        0,
        now(),
        1,
        v_user_id
    );

    SELECT * INTO v_room_record FROM public.rooms WHERE id = v_room_id;

    RETURN jsonb_build_object(
        'id', v_room_record.id,
        'code', v_room_record.code,
        'admin_id', v_room_record.admin_id,
        'is_active', v_room_record.is_active,
        'created_at', v_room_record.created_at
    );
END;
$$;

-- RPC: join_room
CREATE OR REPLACE FUNCTION public.join_room(
    p_code TEXT,
    p_display_name TEXT DEFAULT 'Listener',
    p_avatar_url TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_room RECORD;
    v_member_count INTEGER;
    v_clean_code TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to join a room.';
    END IF;

    v_clean_code := upper(trim(p_code));

    -- Locate active room
    SELECT * INTO v_room
    FROM public.rooms
    WHERE code = v_clean_code AND is_active = true
    LIMIT 1;

    IF v_room IS NULL THEN
        -- Check if it was ended
        IF EXISTS (SELECT 1 FROM public.rooms WHERE code = v_clean_code AND is_active = false) THEN
            RAISE EXCEPTION 'Room has ended.';
        ELSE
            RAISE EXCEPTION 'Room not found. Please check the 6-character code.';
        END IF;
    END IF;

    -- Check member capacity (limit of 20 active members)
    SELECT count(*) INTO v_member_count
    FROM public.room_members
    WHERE room_id = v_room.id AND left_at IS NULL;

    IF v_member_count >= 20 THEN
        RAISE EXCEPTION 'Room is full (maximum 20 listeners).';
    END IF;

    -- Upsert membership
    INSERT INTO public.room_members (room_id, user_id, role, display_name, avatar_url, is_ready, joined_at, left_at)
    VALUES (
        v_room.id,
        v_user_id,
        CASE WHEN v_room.admin_id = v_user_id THEN 'admin' ELSE 'listener' END,
        COALESCE(NULLIF(p_display_name, ''), 'Listener'),
        p_avatar_url,
        false,
        now(),
        NULL
    )
    ON CONFLICT (room_id, user_id) DO UPDATE
    SET left_at = NULL,
        display_name = EXCLUDED.display_name,
        avatar_url = EXCLUDED.avatar_url,
        joined_at = now();

    RETURN jsonb_build_object(
        'id', v_room.id,
        'code', v_room.code,
        'admin_id', v_room.admin_id,
        'is_active', v_room.is_active,
        'created_at', v_room.created_at
    );
END;
$$;

-- RPC: leave_room
CREATE OR REPLACE FUNCTION public.leave_room(p_room_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_admin BOOLEAN;
    v_next_controller UUID;
BEGIN
    -- Mark member left
    UPDATE public.room_members
    SET left_at = now()
    WHERE room_id = p_room_id AND user_id = v_user_id;

    -- Check if leaving user was admin
    SELECT (admin_id = v_user_id) INTO v_is_admin
    FROM public.rooms
    WHERE id = p_room_id;

    IF v_is_admin THEN
        -- Attempt to promote longest connected Controller
        SELECT user_id INTO v_next_controller
        FROM public.room_members
        WHERE room_id = p_room_id AND left_at IS NULL AND role = 'controller'
        ORDER BY joined_at ASC
        LIMIT 1;

        IF v_next_controller IS NOT NULL THEN
            UPDATE public.rooms SET admin_id = v_next_controller WHERE id = p_room_id;
            UPDATE public.room_members SET role = 'admin' WHERE room_id = p_room_id AND user_id = v_next_controller;
        ELSE
            -- End room if no active members remaining
            UPDATE public.rooms SET is_active = false, ended_at = now() WHERE id = p_room_id;
        END IF;
    END IF;
END;
$$;

-- RPC: end_room
CREATE OR REPLACE FUNCTION public.end_room(p_room_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id AND admin_id = v_user_id) THEN
        RAISE EXCEPTION 'Only the room host can end the room.';
    END IF;

    UPDATE public.rooms
    SET is_active = false, ended_at = now()
    WHERE id = p_room_id;

    -- Pause playback
    UPDATE public.room_playback_state
    SET is_playing = false, updated_at_server = now(), version = version + 1, updated_by = v_user_id
    WHERE room_id = p_room_id;
END;
$$;

-- RPC: set_member_role
CREATE OR REPLACE FUNCTION public.set_member_role(
    p_room_id UUID,
    p_target_user_id UUID,
    p_role TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id AND admin_id = v_user_id) THEN
        RAISE EXCEPTION 'Only the room host can change member permissions.';
    END IF;

    IF p_role NOT IN ('controller', 'listener') THEN
        RAISE EXCEPTION 'Invalid role. Only controller or listener can be assigned.';
    END IF;

    UPDATE public.room_members
    SET role = p_role
    WHERE room_id = p_room_id AND user_id = p_target_user_id AND left_at IS NULL;
END;
$$;

-- RPC: remove_member
CREATE OR REPLACE FUNCTION public.remove_member(
    p_room_id UUID,
    p_target_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id AND admin_id = v_user_id) THEN
        RAISE EXCEPTION 'Only the room host can remove members.';
    END IF;

    UPDATE public.room_members
    SET left_at = now()
    WHERE room_id = p_room_id AND user_id = p_target_user_id;
END;
$$;

-- RPC: update_room_playback
CREATE OR REPLACE FUNCTION public.update_room_playback(
    p_room_id UUID,
    p_current_track_id TEXT,
    p_track_metadata JSONB,
    p_is_playing BOOLEAN,
    p_position_ms INTEGER,
    p_scheduled_start_server_ms BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_updated RECORD;
BEGIN
    v_role := public.get_room_member_role(p_room_id, v_user_id);
    IF v_role NOT IN ('admin', 'controller') THEN
        RAISE EXCEPTION 'Only the host or a controller can update playback.';
    END IF;

    UPDATE public.room_playback_state
    SET current_track_id = p_current_track_id,
        current_track_metadata = p_track_metadata,
        is_playing = p_is_playing,
        position_ms = p_position_ms,
        scheduled_start_server_ms = p_scheduled_start_server_ms,
        updated_at_server = now(),
        version = version + 1,
        updated_by = v_user_id
    WHERE room_id = p_room_id
    RETURNING * INTO v_updated;

    RETURN to_jsonb(v_updated);
END;
$$;

-- RPC: set_member_ready
CREATE OR REPLACE FUNCTION public.set_member_ready(
    p_room_id UUID,
    p_is_ready BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.room_members
    SET is_ready = p_is_ready
    WHERE room_id = p_room_id AND user_id = auth.uid() AND left_at IS NULL;
END;
$$;

-- RPC: add_to_room_queue
CREATE OR REPLACE FUNCTION public.add_to_room_queue(
    p_room_id UUID,
    p_track_id TEXT,
    p_track_metadata JSONB,
    p_added_by_name TEXT DEFAULT 'Member'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_max_pos INTEGER;
    v_inserted RECORD;
BEGIN
    v_role := public.get_room_member_role(p_room_id, v_user_id);
    IF v_role NOT IN ('admin', 'controller') THEN
        RAISE EXCEPTION 'Only the host or a controller can add songs to the queue.';
    END IF;

    SELECT COALESCE(MAX(position), -1) + 1 INTO v_max_pos
    FROM public.room_queue
    WHERE room_id = p_room_id;

    INSERT INTO public.room_queue (
        room_id,
        track_id,
        track_metadata,
        position,
        added_by,
        added_by_name,
        created_at
    ) VALUES (
        p_room_id,
        p_track_id,
        p_track_metadata,
        v_max_pos,
        v_user_id,
        COALESCE(NULLIF(p_added_by_name, ''), 'Member'),
        now()
    )
    RETURNING * INTO v_inserted;

    RETURN to_jsonb(v_inserted);
END;
$$;

-- RPC: remove_from_room_queue
CREATE OR REPLACE FUNCTION public.remove_from_room_queue(
    p_room_id UUID,
    p_queue_item_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
BEGIN
    v_role := public.get_room_member_role(p_room_id, v_user_id);
    IF v_role NOT IN ('admin', 'controller') THEN
        RAISE EXCEPTION 'Only the host or a controller can remove songs from the queue.';
    END IF;

    DELETE FROM public.room_queue
    WHERE id = p_queue_item_id AND room_id = p_room_id;
END;
$$;

-- RPC: reorder_room_queue
CREATE OR REPLACE FUNCTION public.reorder_room_queue(
    p_room_id UUID,
    p_item_ids UUID[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    i INTEGER;
BEGIN
    v_role := public.get_room_member_role(p_room_id, v_user_id);
    IF v_role NOT IN ('admin', 'controller') THEN
        RAISE EXCEPTION 'Only the host or a controller can reorder the queue.';
    END IF;

    FOR i IN 1..array_length(p_item_ids, 1) LOOP
        UPDATE public.room_queue
        SET position = i - 1
        WHERE id = p_item_ids[i] AND room_id = p_room_id;
    END LOOP;
END;
$$;
