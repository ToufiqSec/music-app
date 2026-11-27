from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


OUT = r"C:\Users\lutfa\OneDrive\Desktop\Project 1\Swarva_Bug_Audit_Report_2026-11-28.docx"

NAVY = "21364A"
TEAL = "187C82"
SLATE = "526273"
PALE = "EDF3F6"
PALE_ALT = "F7F9FA"
WHITE = "FFFFFF"
TEXT = "202A33"


def shade(cell, fill):
    pr = cell._tc.get_or_add_tcPr()
    shd = pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        pr.append(shd)
    shd.set(qn("w:fill"), fill)


def cell_margins(cell, top=100, start=110, bottom=100, end=110):
    pr = cell._tc.get_or_add_tcPr()
    margins = pr.first_child_found_in("w:tcMar")
    if margins is None:
        margins = OxmlElement("w:tcMar")
        pr.append(margins)
    for side, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = margins.find(qn(f"w:{side}"))
        if node is None:
            node = OxmlElement(f"w:{side}")
            margins.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    repeat = OxmlElement("w:tblHeader")
    repeat.set(qn("w:val"), "true")
    tr_pr.append(repeat)


def set_cell_text(cell, text, *, bold=False, color=TEXT, size=9.2):
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.04
    run = p.add_run(text)
    run.bold = bold
    run.font.name = "Aptos"
    run.font.size = Pt(size)
    run.font.color.rgb = RGBColor.from_string(color)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def add_labeled_paragraph(doc, label, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(5)
    p.paragraph_format.line_spacing = 1.08
    r = p.add_run(label + "  ")
    r.bold = True
    r.font.color.rgb = RGBColor.from_string(NAVY)
    p.add_run(text)
    return p


def add_page_field(paragraph):
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = " PAGE "
    separate = OxmlElement("w:fldChar")
    separate.set(qn("w:fldCharType"), "separate")
    text = OxmlElement("w:t")
    text.text = "1"
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, instr, separate, text, end])


doc = Document()
section = doc.sections[0]
section.page_width = Inches(8.5)
section.page_height = Inches(11)
section.top_margin = Inches(0.68)
section.bottom_margin = Inches(0.65)
section.left_margin = Inches(0.78)
section.right_margin = Inches(0.78)
section.header_distance = Inches(0.32)
section.footer_distance = Inches(0.32)

styles = doc.styles
normal = styles["Normal"]
normal.font.name = "Aptos"
normal.font.size = Pt(10.3)
normal.font.color.rgb = RGBColor.from_string(TEXT)
normal.paragraph_format.space_after = Pt(6)
normal.paragraph_format.line_spacing = 1.08

for name, size, color, before, after in [
    ("Title", 25, NAVY, 0, 3),
    ("Heading 1", 15, NAVY, 11, 5),
    ("Heading 2", 12, TEAL, 8, 3),
    ("Heading 3", 10.5, NAVY, 5, 2),
]:
    style = styles[name]
    style.font.name = "Aptos Display" if name in ("Title", "Heading 1", "Heading 2") else "Aptos"
    style.font.size = Pt(size)
    style.font.bold = True
    style.font.color.rgb = RGBColor.from_string(color)
    style.paragraph_format.space_before = Pt(before)
    style.paragraph_format.space_after = Pt(after)
    style.paragraph_format.keep_with_next = True

# Some Word themes add a bottom rule to the built-in Title style.
title_style_ppr = styles["Title"]._element.get_or_add_pPr()
for border in title_style_ppr.findall(qn("w:pBdr")):
    title_style_ppr.remove(border)

header = section.header.paragraphs[0]
header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
header.paragraph_format.space_after = Pt(0)
hr = header.add_run("SWARVA  /  APP REVIEW")
hr.font.name = "Aptos"
hr.font.size = Pt(8)
hr.font.bold = True
hr.font.color.rgb = RGBColor.from_string(SLATE)

footer = section.footer.paragraphs[0]
footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
footer.paragraph_format.space_before = Pt(0)
fr = footer.add_run("Static source review  •  28 November 2026  •  Page ")
fr.font.name = "Aptos"
fr.font.size = Pt(8)
fr.font.color.rgb = RGBColor.from_string(SLATE)
add_page_field(footer)

# First page
title = doc.add_paragraph(style="Title")
title.add_run("Swarva App Bug Audit")
title_ppr = title._p.get_or_add_pPr()
for border in title_ppr.findall(qn("w:pBdr")):
    title_ppr.remove(border)
subtitle = doc.add_paragraph()
subtitle.paragraph_format.space_after = Pt(10)
sr = subtitle.add_run("Findings from the checked-in Flutter and Android code")
sr.font.name = "Aptos"
sr.font.size = Pt(11)
sr.font.color.rgb = RGBColor.from_string(SLATE)

meta = doc.add_paragraph()
meta.paragraph_format.space_after = Pt(10)
mr = meta.add_run("Review date  28 November 2026     |     Review type  Static source review")
mr.font.size = Pt(8.8)
mr.font.color.rgb = RGBColor.from_string(TEAL)

doc.add_heading("Summary", level=1)
doc.add_paragraph(
    "I found four actionable issues in the checked-in app. The release signing key and its password are stored in the repository. The app signs users in with Firebase while cloud sync and shared listening rooms check Supabase for the signed-in user, so those features can behave as if the user is logged out. Android also blocks some HTTP audio sources the playback resolver intentionally keeps, and mood mixes do not guarantee the 15 tracks required by the project rules."
)

summary_items = [
    ("HIGH", "Release signing credentials are exposed.", "Repository access could enable app-signed updates."),
    ("HIGH", "Firebase and Supabase sessions are disconnected.", "Cloud sync and room actions can fail after login."),
    ("MEDIUM", "Android blocks supported HTTP audio sources.", "LAN and custom-port streams can fail to play."),
    ("MEDIUM", "Mood mixes do not guarantee 15 tracks.", "The fallback only fills results to five tracks."),
]
for level, finding, effect in summary_items:
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.left_indent = Inches(0.22)
    p.paragraph_format.first_line_indent = Inches(-0.16)
    p.paragraph_format.space_after = Pt(2.5)
    p.paragraph_format.line_spacing = 1.03
    level_run = p.add_run(level + "  ")
    level_run.bold = True
    level_run.font.color.rgb = RGBColor.from_string(TEAL)
    finding_run = p.add_run(finding + " ")
    finding_run.bold = True
    p.add_run(effect)

doc.add_heading("Review scope", level=1)
doc.add_paragraph(
    "I reviewed the Flutter app, Android configuration, project rules, existing diagnosis notes, and checked-in tests as source material. I did not run tests or launch the app. The Flutter and Dart commands are unavailable in this workspace, and Supabase deployment settings are outside the checked-in files."
)
doc.add_paragraph(
    "The findings below are supported by source references. The separate project gaps section identifies requirements or backend setup that could not be confirmed as working from this repository alone."
)

# Detailed findings, page 2
doc.add_page_break()
doc.add_heading("Confirmed findings", level=1)

doc.add_heading("Finding 1  Release signing credentials are exposed", level=2)
add_labeled_paragraph(doc, "Severity", "High security risk")
add_labeled_paragraph(
    doc,
    "Impact",
    "The Android release configuration includes signing passwords in source, and the matching release keystore is tracked in Git. Anyone with repository access can use the same signing identity to produce an app update. Treat this signing identity as exposed."
)
add_labeled_paragraph(
    doc,
    "Evidence",
    "android/app/build.gradle lines 46–51 define the release keystore and passwords. Git tracks android/app/release.jks."
)
add_labeled_paragraph(
    doc,
    "Recommended fix",
    "Move signing secrets out of source control and load them from protected local or CI secrets. Remove the keystore from future repository history where practical. Follow the appropriate signing-key rotation process for the app’s distribution channel."
)

doc.add_heading("Finding 2  Firebase and Supabase sessions are disconnected", level=2)
add_labeled_paragraph(doc, "Severity", "High functional risk")
add_labeled_paragraph(
    doc,
    "Impact",
    "The app reports a user as signed in through Firebase, but Supabase-backed features read Supabase’s own auth session. On a fresh install, Firebase login does not create a Supabase session. Cloud settings, playlists, listening history, and shared-room operations can therefore return early or reject the user as logged out."
)
add_labeled_paragraph(
    doc,
    "Evidence",
    "lib/providers/auth_provider.dart lines 18–20 and 109–149 use Firebase for identity and email login. lib/core/services/supabase_service.dart lines 102–103 reads Supabase auth; lines 317–320 and 361–363 return defaults or stop when no Supabase user exists. lib/features/listen_together/services/room_service.dart lines 34–37 and 99–102 rejects room creation and joining without a Supabase user."
)
add_labeled_paragraph(
    doc,
    "How to confirm",
    "On a clean install, sign in with the app’s email or Google flow, then change a cloud setting or try to create a listening room. The Firebase profile can show as signed in while Supabase operations still see no user."
)
add_labeled_paragraph(
    doc,
    "Recommended fix",
    "Use one identity system consistently, or configure a trusted Firebase-to-Supabase authentication bridge. Ensure server-side authorization validates the user token; passing a Firebase UID from the client alone is not sufficient."
)

# Detailed findings, page 3
doc.add_page_break()
doc.add_heading("Confirmed findings continued", level=1)

doc.add_heading("Finding 3  Android blocks supported HTTP audio sources", level=2)
add_labeled_paragraph(doc, "Severity", "Medium playback risk")
add_labeled_paragraph(
    doc,
    "Impact",
    "The playback resolver intentionally preserves plain HTTP for private LAN addresses, local hostnames, and nonstandard ports. Android’s network security configuration blocks cleartext traffic globally and allows it only for localhost and 127.0.0.1. A stream such as an HTTP radio URL on a LAN address or port 8000 can pass the resolver and still be rejected by Android."
)
add_labeled_paragraph(
    doc,
    "Evidence",
    "lib/core/services/playback_resolver.dart lines 56–80 preserves these HTTP URLs. android/app/src/main/AndroidManifest.xml line 30 disables cleartext traffic. android/app/src/main/res/xml/network_security_config.xml lines 3–13 denies it globally except loopback."
)
add_labeled_paragraph(
    doc,
    "How to confirm",
    "On Android, play a valid HTTP-only LAN or custom-port audio stream. Compare with the same stream served over HTTPS."
)
add_labeled_paragraph(
    doc,
    "Recommended fix",
    "Align the supported stream types with Android’s network policy. Prefer HTTPS sources, or permit only the specific cleartext sources the app must support."
)

doc.add_heading("Finding 4  Mood mixes do not guarantee 15 tracks", level=2)
add_labeled_paragraph(doc, "Severity", "Medium product-rule gap")
add_labeled_paragraph(
    doc,
    "Impact",
    "The project rules require at least 15 recommendations. When the initial searches return fewer results, the fallback in the mood engine stops once it reaches five, then returns the list as-is. A mood mix can therefore contain fewer than the required 15 tracks."
)
add_labeled_paragraph(
    doc,
    "Evidence",
    "AGENT.md line 3 sets the 15-track minimum. lib/core/services/mood_recommendation_engine.dart lines 203–218 tops up only to five; lines 227–230 returns the resulting list. The same result is passed through TasteEngine’s artist-spacing logic, so that separate rule is present in the reviewed path."
)
add_labeled_paragraph(
    doc,
    "How to confirm",
    "Use mood searches that produce five to fourteen unique tracks after filtering. The engine can return fewer than 15."
)
add_labeled_paragraph(
    doc,
    "Recommended fix",
    "Continue searching or use a documented fallback until there are 15 valid, unique tracks. If the sources cannot provide 15, show that fewer results are available instead of treating five as the minimum."
)

# Scope gaps and limitations, page 4
doc.add_page_break()
doc.add_heading("Project gaps and external dependencies", level=1)
doc.add_paragraph(
    "These items are not counted as confirmed runtime defects because this workspace cannot establish whether they exist in a separately managed backend or later branch. They should be checked before calling the feature set complete."
)

doc.add_heading("Planned features not found in the workspace", level=2)
doc.add_paragraph(
    "AGENT.md and docs/SPECS.md call for artist-to-fan broadcast channels and a collaborative Blend playlist that combines users’ listening tastes. I found no corresponding implementation or backend schema in the checked-in app. Listen Together rooms cover synchronized playback, but they do not implement either of those features."
)

doc.add_heading("Podcast service deployment files", level=2)
doc.add_paragraph(
    "lib/core/services/podcast_rss_service.dart calls the fetch-podcasts Supabase Edge Function and reads the podcast_episodes table. No Edge Function source or podcast table migration is present in this workspace; the checked-in Supabase SQL file defines listening-room tables. If these resources are deployed separately, record their setup and access rules alongside the app. Otherwise the live episode path cannot be provisioned from this repository and the client falls back to curated episodes."
)

doc.add_heading("Diagnosis note does not match current login code", level=2)
doc.add_paragraph(
    "DIAGNOSIS.md describes sign-in as a Supabase flow. The current AuthProvider and login screen use FirebaseAuthService. Update the diagnosis so future troubleshooting targets the active auth path and the Firebase–Supabase session boundary described in Finding 2."
)

doc.add_heading("Verification limits", level=2)
doc.add_paragraph(
    "This was a static review of the checked-in workspace. I did not add or run tests, and I could not run Flutter analysis or launch the app because Flutter and Dart executables are not available here. I also could not inspect the live Supabase project, its policies, deployed functions, or Android device behavior. Those checks may reveal additional issues or confirm separately managed dependencies."
)

doc.core_properties.title = "Swarva App Bug Audit"
doc.core_properties.subject = "Static review findings for the Swarva Flutter and Android app"
doc.core_properties.author = "OpenAI"
doc.core_properties.keywords = "bug audit, Flutter, Android, Swarva"
doc.save(OUT)
print(OUT)
