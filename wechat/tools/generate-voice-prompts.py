#!/usr/bin/env python3
"""
tools/generate-voice-prompts.py
RF-305: Generate mp3 voice prompt files from prompts.json for WeChat mini-program.

Uses edge-tts (recommended, natural Microsoft voices) or falls back to gTTS.
Output: assets/audio/{lang}/{key}.mp3

Usage:
    python tools/generate-voice-prompts.py                    # generate all
    python tools/generate-voice-prompts.py --lang zh           # Chinese only
    python tools/generate-voice-prompts.py --lang en           # English only
    python tools/generate-voice-prompts.py --key cadence_low   # single prompt
    python tools/generate-voice-prompts.py --dry-run           # print what would be generated

Dependencies:
    pip install edge-tts    # or: pip install gTTS

Voice selection (edge-tts):
    zh-CN: zh-CN-XiaoxiaoNeural (female, warm)
    en-US: en-US-JennyNeural (female, clear)
"""

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

# Project paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent
PROMPTS_PATH = PROJECT_ROOT / 'prompts.json'
AUDIO_OUTPUT = PROJECT_ROOT / 'assets' / 'audio'

# Voice configurations for edge-tts
VOICES = {
    'zh': 'zh-CN-XiaoxiaoNeural',   # Xiaoxiao - warm female Chinese
    'en': 'en-US-JennyNeural',       # Jenny - clear female English
}

# gTTS language codes (fallback)
GTTS_LANGS = {
    'zh': 'zh-CN',
    'en': 'en',
}


def load_prompts():
    """Load prompts.json and return the prompts dict."""
    if not PROMPTS_PATH.exists():
        print(f'❌ prompts.json not found at {PROMPTS_PATH}')
        sys.exit(1)
    with open(PROMPTS_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data.get('prompts', {})


async def generate_edge_tts(text, voice, output_path, key, lang):
    """Generate mp3 using edge-tts (async)."""
    try:
        import edge_tts
    except ImportError:
        return False

    communicate = edge_tts.Communicate(text, voice)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    await communicate.save(str(output_path))
    return True


def generate_gtts(text, lang_code, output_path):
    """Generate mp3 using gTTS (sync, fallback)."""
    try:
        from gtts import gTTS
    except ImportError:
        return False

    output_path.parent.mkdir(parents=True, exist_ok=True)
    tts = gTTS(text=text, lang=lang_code, slow=False)
    tts.save(str(output_path))
    return True


async def generate_prompt(key, prompts_data, langs, dry_run=False):
    """Generate audio files for a single prompt key in specified languages."""
    results = []

    for lang in langs:
        text = prompts_data.get(key, {}).get(lang)
        if not text:
            print(f'  ⚠️  No text for key={key} lang={lang}, skipping')
            continue

        output_path = AUDIO_OUTPUT / lang / f'{key}.mp3'

        if dry_run:
            print(f'  [DRY-RUN] Would generate: {output_path}')
            print(f'           Text: {text[:60]}...')
            results.append(('dry_run', key, lang))
            continue

        if output_path.exists():
            print(f'  ⏭️  Already exists: {output_path}')
            results.append(('skipped', key, lang))
            continue

        # Try edge-tts first (better quality)
        voice = VOICES.get(lang, VOICES['en'])
        success = await generate_edge_tts(text, voice, output_path, key, lang)

        if not success:
            # Fallback to gTTS
            print(f'  ℹ️  edge-tts unavailable, trying gTTS...')
            gtts_lang = GTTS_LANGS.get(lang, 'en')
            success = generate_gtts(text, gtts_lang, output_path)

        if success:
            size_kb = output_path.stat().st_size / 1024
            print(f'  ✅ Generated: {output_path} ({size_kb:.1f} KB)')
            results.append(('ok', key, lang))
        else:
            print(f'  ❌ Failed: {key}/{lang} — install edge-tts or gTTS')
            print(f'     pip install edge-tts')
            results.append(('error', key, lang))

    return results


async def main():
    parser = argparse.ArgumentParser(
        description='Generate voice prompt mp3 files for WeChat mini-program'
    )
    parser.add_argument('--lang', choices=['zh', 'en'], help='Generate only one language')
    parser.add_argument('--key', help='Generate only a specific prompt key')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be generated')
    args = parser.parse_args()

    # Load prompts
    prompts_data = load_prompts()
    lang_keys = [args.lang] if args.lang else ['zh', 'en']
    prompt_keys = [args.key] if args.key else list(prompts_data.keys())

    if args.key and args.key not in prompts_data:
        print(f'❌ Unknown prompt key: {args.key}')
        print(f'   Available keys: {", ".join(sorted(prompts_data.keys()))}')
        sys.exit(1)

    total_prompts = len(prompt_keys) * len(lang_keys)
    print(f'🎙️  Generating {total_prompts} voice prompts...')
    print(f'   Output: {AUDIO_OUTPUT}/')
    print(f'   Languages: {lang_keys}')
    if args.dry_run:
        print(f'   Mode: DRY-RUN (no files will be written)')
    print()

    # Generate sequentially to avoid rate-limiting edge-tts
    results = []
    for key in sorted(prompt_keys):
        print(f'📝 {key}')
        res = await generate_prompt(key, prompts_data, lang_keys, dry_run=args.dry_run)
        results.extend(res)

    # Summary
    print()
    ok = sum(1 for r in results if r[0] == 'ok')
    skipped = sum(1 for r in results if r[0] == 'skipped')
    dry = sum(1 for r in results if r[0] == 'dry_run')
    errors = sum(1 for r in results if r[0] == 'error')

    print(f'━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    print(f'  ✅ Generated: {ok}')
    print(f'  ⏭️  Skipped:  {skipped}')
    if dry:
        print(f'  🔍 Dry-run:  {dry}')
    if errors:
        print(f'  ❌ Errors:   {errors}')
    print(f'━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    if errors:
        print()
        print('💡 Install a TTS backend:')
        print('   pip install edge-tts   # Recommended (natural voices)')
        print('   pip install gTTS       # Fallback (robotic but no async)')

    if errors > 0:
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())
