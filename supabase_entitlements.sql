-- ============================================================================
-- SUPABASE MIGRATION: User Entitlements (Free / Premium Plan Management)
-- ============================================================================
-- Run this script in your Supabase SQL Editor.
-- Users can read their own entitlement status, but only service_role / admins
-- can grant or revoke plans (Problem 11).

CREATE TABLE IF NOT EXISTS public.user_entitlements (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'premium')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own entitlement" ON public.user_entitlements;
CREATE POLICY "Users can read their own entitlement"
    ON public.user_entitlements FOR SELECT
    USING (auth.uid() = user_id);
