#!/usr/bin/env python3
"""
LinkedIn Auto-Reply Bot – Hauptskript
=====================================

Verwendung:
    python run.py scrape                    # Letzte 5 Posts scrapen
    python run.py scrape --url <post-url>   # Bestimmten Post scrapen
    python run.py scrape --max 3            # Nur letzte 3 Posts
    python run.py reply                     # Antworten posten
    python run.py reply --dry-run           # Vorschau ohne zu posten
    python run.py status                    # Aktuellen Stand anzeigen
"""

import argparse
import json
import sys
from pathlib import Path

import yaml

from scrape_comments import scrape
from post_replies import post_replies

CONFIG_FILE = Path(__file__).parent / "config.yaml"
COMMENTS_DIR = Path(__file__).parent / "comments"
COMMENTS_FILE = COMMENTS_DIR / "comments.json"
REPLIES_FILE = COMMENTS_DIR / "replies.json"


def load_config() -> dict:
    """Lädt die config.yaml."""
    if not CONFIG_FILE.exists():
        print("❌ config.yaml nicht gefunden!")
        print(f"   Erstelle eine unter: {CONFIG_FILE}")
        sys.exit(1)

    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def cmd_scrape(args):
    """Scrapt Kommentare von LinkedIn Posts."""
    config = load_config()
    print("\n🚀 LinkedIn Comment Scraper")
    print("=" * 50)

    results = scrape(
        post_url=args.url,
        max_posts=args.max,
        config=config,
    )

    if results:
        total = sum(r["kommentare_zu_beantworten"] for r in results)
        if total > 0:
            print("👉 Nächster Schritt:")
            print('   Sag in Claude Code:')
            print('   "Lies linkedin-reply/comments/comments.json und')
            print('    linkedin-reply/config.yaml und generiere Antworten')
            print('    für alle Kommentare mit status needs_reply.')
            print('    Speichere das Ergebnis als linkedin-reply/comments/replies.json"')
        else:
            print("✅ Keine Kommentare zu beantworten!")


def cmd_reply(args):
    """Postet generierte Antworten auf LinkedIn."""
    print("\n🚀 LinkedIn Reply Poster")
    print("=" * 50)

    post_replies(dry_run=args.dry_run)


def cmd_status(args):
    """Zeigt den aktuellen Stand an."""
    print("\n📊 LinkedIn Auto-Reply – Status")
    print("=" * 50)

    # Comments
    if COMMENTS_FILE.exists():
        with open(COMMENTS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)

        total_posts = len(data)
        total_comments = sum(p.get("kommentare_gesamt", 0) for p in data)
        to_reply = sum(p.get("kommentare_zu_beantworten", 0) for p in data)

        print(f"\n📄 comments.json:")
        print(f"   Posts:                {total_posts}")
        print(f"   Kommentare gesamt:    {total_comments}")
        print(f"   Zu beantworten:       {to_reply}")

        for post in data:
            print(f"\n   📌 {post.get('post_vorschau', 'N/A')[:70]}...")
            print(f"      URL: {post.get('url', 'N/A')}")
            for k in post.get("kommentare", []):
                status_icon = {
                    "needs_reply": "🟡",
                    "bereits_beantwortet": "✅",
                    "eigener_kommentar": "👤",
                    "spam": "🚫",
                    "zu_kurz": "⏭️",
                }.get(k["status"], "❓")
                print(f"      {status_icon} {k['name']}: \"{k['text'][:50]}...\" [{k['status']}]")
    else:
        print("\n📄 comments.json: Nicht vorhanden")
        print("   → Führe 'python run.py scrape' aus")

    # Replies
    if REPLIES_FILE.exists():
        with open(REPLIES_FILE, "r", encoding="utf-8") as f:
            replies = json.load(f)

        total_replies = sum(
            len([a for a in p.get("antworten", []) if a.get("antwort")])
            for p in replies
        )
        print(f"\n💬 replies.json:")
        print(f"   Generierte Antworten: {total_replies}")
        print(f"   → Führe 'python run.py reply --dry-run' für Vorschau aus")
    else:
        print("\n💬 replies.json: Nicht vorhanden")
        print("   → Lass Claude Code Antworten generieren")

    print()


def main():
    parser = argparse.ArgumentParser(
        description="LinkedIn Auto-Reply Bot",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Workflow:
  1. python run.py scrape              # Kommentare holen
  2. Claude Code: "Generiere Antworten"  # Antworten schreiben lassen
  3. python run.py reply --dry-run     # Vorschau
  4. python run.py reply               # Posten
        """,
    )

    subparsers = parser.add_subparsers(dest="command", help="Verfügbare Befehle")

    # scrape
    scrape_parser = subparsers.add_parser("scrape", help="Kommentare von LinkedIn scrapen")
    scrape_parser.add_argument("--url", type=str, help="Spezifische Post-URL")
    scrape_parser.add_argument("--max", type=int, default=5, help="Max. Anzahl Posts (Standard: 5)")
    scrape_parser.set_defaults(func=cmd_scrape)

    # reply
    reply_parser = subparsers.add_parser("reply", help="Antworten auf LinkedIn posten")
    reply_parser.add_argument("--dry-run", action="store_true", help="Nur Vorschau, nicht posten")
    reply_parser.set_defaults(func=cmd_reply)

    # status
    status_parser = subparsers.add_parser("status", help="Aktuellen Stand anzeigen")
    status_parser.set_defaults(func=cmd_status)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    args.func(args)


if __name__ == "__main__":
    main()
