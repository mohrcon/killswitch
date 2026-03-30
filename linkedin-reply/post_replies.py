"""
LinkedIn Reply Poster – Playwright-basiert
Liest generierte Antworten aus replies.json und postet sie auf LinkedIn.
"""

import json
import time
from pathlib import Path
from playwright.sync_api import sync_playwright, Page, BrowserContext

BROWSER_DATA_DIR = Path(__file__).parent / ".browser-data"
COMMENTS_DIR = Path(__file__).parent / "comments"


def ensure_login(context: BrowserContext) -> Page:
    """Öffnet LinkedIn und prüft ob eingeloggt."""
    page = context.new_page()
    page.goto("https://www.linkedin.com/feed/", wait_until="domcontentloaded")
    time.sleep(3)

    if "/login" in page.url or "/checkpoint" in page.url:
        print("\n🔐 Du bist nicht eingeloggt.")
        print("   Bitte logge dich jetzt im geöffneten Browser ein.")
        page.wait_for_url("**/feed/**", timeout=120_000)
        print("   Login erfolgreich!\n")
        time.sleep(2)

    return page


def find_comment_and_reply(page: Page, comment_name: str, comment_text: str, reply_text: str) -> bool:
    """Findet einen Kommentar auf der Seite und postet eine Antwort darauf.

    Args:
        page: Playwright Page Objekt (bereits auf dem Post)
        comment_name: Name des Kommentators
        comment_text: Text des Kommentars (zur Identifikation)
        reply_text: Die zu postende Antwort

    Returns:
        True wenn erfolgreich, False wenn nicht.
    """
    try:
        # Finde alle Kommentar-Elemente
        comment_elements = page.query_selector_all(
            'article.comments-comment-item, '
            'article.comments-comment-entity, '
            '[data-id][class*="comment"]'
        )

        target_element = None
        comment_text_short = comment_text[:50].lower()

        for el in comment_elements:
            el_text = (el.inner_text() or "").lower()
            # Prüfe ob Name und Textanfang übereinstimmen
            if comment_name.lower() in el_text and comment_text_short in el_text:
                target_element = el
                break

        if not target_element:
            print(f"   ⚠️  Kommentar von {comment_name} nicht gefunden")
            return False

        # "Antworten"-Button im Kommentar finden und klicken
        reply_button = target_element.query_selector(
            'button[aria-label*="Antwort"], '
            'button[aria-label*="Reply"], '
            'button[aria-label*="antwort"], '
            'button.comments-comment-social-bar__reply-btn, '
            'span.reply-button'
        )

        if not reply_button:
            # Fallback: Suche nach dem Text "Antworten" / "Reply"
            buttons = target_element.query_selector_all("button")
            for btn in buttons:
                btn_text = (btn.inner_text() or "").strip().lower()
                if btn_text in ("antworten", "reply", "antwort"):
                    reply_button = btn
                    break

        if not reply_button:
            print(f"   ⚠️  'Antworten'-Button bei {comment_name} nicht gefunden")
            return False

        reply_button.click()
        time.sleep(1.5)

        # Antwort-Textfeld finden und Text eingeben
        # Nach dem Klick auf "Antworten" erscheint ein Textfeld
        reply_editors = page.query_selector_all(
            '.comments-comment-box__form .ql-editor, '
            '[role="textbox"][contenteditable="true"], '
            '.editor-content [contenteditable="true"]'
        )

        # Nehme das zuletzt sichtbare Textfeld (das gerade geöffnete)
        reply_editor = None
        for editor in reversed(reply_editors):
            if editor.is_visible():
                reply_editor = editor
                break

        if not reply_editor:
            print(f"   ⚠️  Antwort-Textfeld nicht gefunden")
            return False

        # Text eingeben
        reply_editor.click()
        time.sleep(0.5)
        reply_editor.fill("")
        reply_editor.type(reply_text, delay=30)  # Menschliches Tipp-Tempo
        time.sleep(1)

        # Absenden-Button finden und klicken
        submit_buttons = page.query_selector_all(
            'button.comments-comment-box__submit-button, '
            'button[type="submit"][class*="comment"], '
            'button[aria-label*="Kommentar posten"], '
            'button[aria-label*="Post comment"]'
        )

        submit_button = None
        for btn in reversed(submit_buttons):
            if btn.is_visible() and btn.is_enabled():
                submit_button = btn
                break

        if not submit_button:
            print(f"   ⚠️  Absenden-Button nicht gefunden")
            return False

        submit_button.click()
        time.sleep(2)

        return True

    except Exception as e:
        print(f"   ❌ Fehler beim Antworten auf {comment_name}: {e}")
        return False


def post_replies(dry_run: bool = False) -> dict:
    """Liest replies.json und postet alle Antworten auf LinkedIn.

    Args:
        dry_run: Wenn True, wird nur angezeigt was gepostet werden würde.

    Returns:
        Zusammenfassung mit Erfolgs-/Fehlerquote.
    """
    replies_file = COMMENTS_DIR / "replies.json"

    if not replies_file.exists():
        print("❌ Keine replies.json gefunden!")
        print("   Generiere zuerst Antworten mit Claude Code:")
        print('   → "Beantworte die Kommentare in linkedin-reply/comments/comments.json"')
        return {"posted": 0, "failed": 0, "skipped": 0}

    with open(replies_file, "r", encoding="utf-8") as f:
        replies_data = json.load(f)

    # Zähle zu postende Antworten
    total_replies = 0
    for post in replies_data:
        for kommentar in post.get("antworten", []):
            if kommentar.get("antwort"):
                total_replies += 1

    if total_replies == 0:
        print("ℹ️  Keine Antworten zu posten.")
        return {"posted": 0, "failed": 0, "skipped": 0}

    if dry_run:
        print(f"\n🔍 DRY RUN – {total_replies} Antworten würden gepostet:\n")
        for post in replies_data:
            print(f"📄 Post: {post.get('url', 'N/A')}")
            for k in post.get("antworten", []):
                if k.get("antwort"):
                    print(f"   💬 {k['name']}: \"{k['kommentar_text'][:60]}...\"")
                    print(f"   ↳  \"{k['antwort'][:80]}...\"\n")
        return {"posted": 0, "failed": 0, "skipped": total_replies}

    # Echtes Posten
    stats = {"posted": 0, "failed": 0, "skipped": 0}

    with sync_playwright() as p:
        context = p.chromium.launch_persistent_context(
            user_data_dir=str(BROWSER_DATA_DIR),
            headless=False,
            viewport={"width": 1280, "height": 900},
            locale="de-DE",
        )

        try:
            page = ensure_login(context)

            for post in replies_data:
                post_url = post.get("url")
                antworten = post.get("antworten", [])

                if not antworten:
                    continue

                print(f"\n📄 Öffne Post: {post_url}")
                page.goto(post_url, wait_until="domcontentloaded")
                time.sleep(3)

                # Alle Kommentare aufklappen
                page.evaluate("window.scrollBy(0, 500)")
                time.sleep(2)

                for k in antworten:
                    if not k.get("antwort"):
                        stats["skipped"] += 1
                        continue

                    print(f"\n   💬 Antworte auf {k['name']}...")
                    success = find_comment_and_reply(
                        page,
                        comment_name=k["name"],
                        comment_text=k["kommentar_text"],
                        reply_text=k["antwort"],
                    )

                    if success:
                        stats["posted"] += 1
                        print(f"   ✅ Gepostet!")
                    else:
                        stats["failed"] += 1
                        print(f"   ❌ Fehlgeschlagen")

                    # Pause zwischen Antworten (natürliches Verhalten)
                    time.sleep(3)

        finally:
            context.close()

    print(f"\n{'='*50}")
    print(f"📊 Ergebnis:")
    print(f"   Gepostet:       {stats['posted']}")
    print(f"   Fehlgeschlagen: {stats['failed']}")
    print(f"   Übersprungen:   {stats['skipped']}")
    print(f"{'='*50}\n")

    return stats
