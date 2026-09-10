#!/usr/bin/env python3
import os
import re
import json
import time
import urllib.request
import urllib.parse
import sys

# Target locales mapping: KDE Locale Code -> { Name, Google Translate Code }
# (Note: en-US is the source language and does not need a po file)
LOCALES = {
    'af': {'name': 'Afrikaans', 'gt': 'af'},
    'am': {'name': 'Amharic', 'gt': 'am'},
    'ar': {'name': 'Arabic', 'gt': 'ar'},
    'bg': {'name': 'Bulgarian', 'gt': 'bg'},
    'bn': {'name': 'Bengali', 'gt': 'bn'},
    'ca': {'name': 'Catalan', 'gt': 'ca'},
    'cs': {'name': 'Czech', 'gt': 'cs'},
    'da': {'name': 'Danish', 'gt': 'da'},
    'de': {'name': 'German', 'gt': 'de'},
    'el': {'name': 'Greek', 'gt': 'el'},
    'en_GB': {'name': 'English (United Kingdom)', 'gt': 'en-GB'},
    'es': {'name': 'Spanish', 'gt': 'es'},
    'es_419': {'name': 'Spanish (Latin America)', 'gt': 'es-419'},
    'et': {'name': 'Estonian', 'gt': 'et'},
    'fa': {'name': 'Persian', 'gt': 'fa'},
    'fi': {'name': 'Finnish', 'gt': 'fi'},
    'fil': {'name': 'Filipino', 'gt': 'tl'},
    'fr': {'name': 'French', 'gt': 'fr'},
    'gu': {'name': 'Gujarati', 'gt': 'gu'},
    'he': {'name': 'Hebrew', 'gt': 'he'},
    'hi': {'name': 'Hindi', 'gt': 'hi'},
    'hr': {'name': 'Croatian', 'gt': 'hr'},
    'hu': {'name': 'Hungarian', 'gt': 'hu'},
    'id': {'name': 'Indonesian', 'gt': 'id'},
    'it': {'name': 'Italian', 'gt': 'it'},
    'ja': {'name': 'Japanese', 'gt': 'ja'},
    'kn': {'name': 'Kannada', 'gt': 'kn'},
    'ko': {'name': 'Korean', 'gt': 'ko'},
    'lt': {'name': 'Lithuanian', 'gt': 'lt'},
    'lv': {'name': 'Latvian', 'gt': 'lv'},
    'ml': {'name': 'Malayalam', 'gt': 'ml'},
    'mr': {'name': 'Marathi', 'gt': 'mr'},
    'ms': {'name': 'Malay', 'gt': 'ms'},
    'nb': {'name': 'Norwegian Bokmål', 'gt': 'no'},
    'nl': {'name': 'Dutch', 'gt': 'nl'},
    'pl': {'name': 'Polish', 'gt': 'pl'},
    'pt_BR': {'name': 'Portuguese (Brazil)', 'gt': 'pt-BR'},
    'pt_PT': {'name': 'Portuguese (Portugal)', 'gt': 'pt-PT'},
    'ro': {'name': 'Romanian', 'gt': 'ro'},
    'ru': {'name': 'Russian', 'gt': 'ru'},
    'sk': {'name': 'Slovak', 'gt': 'sk'},
    'sl': {'name': 'Slovenian', 'gt': 'sl'},
    'sr': {'name': 'Serbian', 'gt': 'sr'},
    'sv': {'name': 'Swedish', 'gt': 'sv'},
    'sw': {'name': 'Swahili', 'gt': 'sw'},
    'ta': {'name': 'Tamil', 'gt': 'ta'},
    'te': {'name': 'Telugu', 'gt': 'te'},
    'th': {'name': 'Thai', 'gt': 'th'},
    'tr': {'name': 'Turkish', 'gt': 'tr'},
    'uk': {'name': 'Ukrainian', 'gt': 'uk'},
    'ur': {'name': 'Urdu', 'gt': 'ur'},
    'vi': {'name': 'Vietnamese', 'gt': 'vi'},
    'zh_CN': {'name': 'Chinese (Simplified)', 'gt': 'zh-CN'},
    'zh_TW': {'name': 'Chinese (Traditional)', 'gt': 'zh-TW'}
}

# The main description string to be translated for metadata files
DESCRIPTION_SRC = "Fitbit step counter and fitness data widget for KDE Plasma"

def translate(text, target_lang, source_lang='en'):
    if not text.strip():
        return text
    
    # Handle newline splitting
    if '\n' in text:
        parts = text.split('\n')
        translated_parts = []
        for p in parts:
            translated_parts.append(translate(p, target_lang, source_lang))
        return '\n'.join(translated_parts)
    
    # Tokenize QML/C format placeholders: %1%, %1, %2, %3, %4
    # (keeps Google Translate from translating or messing up placeholders)
    placeholder_list = [
        ('%1%', ' XPTONEPERCENT '),
        ('%1', ' XPTONE '),
        ('%2', ' XPTTWO '),
        ('%3', ' XPTTHREE '),
        ('%4', ' XPTFOUR ')
    ]
    work_text = text
    for placeholder, token in placeholder_list:
        work_text = work_text.replace(placeholder, token)
        
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source_lang}&tl={target_lang}&dt=t&q={urllib.parse.quote(work_text)}"
    req = urllib.request.Request(
        url, 
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    )
    
    translated_text = ""
    max_retries = 5
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode('utf-8'))
                translated_text = "".join([segment[0] for segment in data[0] if segment[0]])
                break
        except Exception as e:
            if attempt == max_retries - 1:
                print(f"Error calling GT for '{text}' to {target_lang}: {e}", file=sys.stderr)
                return text # Fallback
            time.sleep(1.5)
            
    # Restore placeholders
    restored = translated_text
    token_patterns = [
        ('%1%', ['xptonepercent', 'xpt-onepercent', 'xpt_onepercent', 'xptone%']),
        ('%1', ['xptone', 'xpt-one', 'xpt_one']),
        ('%2', ['xpttwo', 'xpt-two', 'xpt_two']),
        ('%3', ['xptthree', 'xpt-three', 'xpt_three']),
        ('%4', ['xptfour', 'xpt-four', 'xpt_four'])
    ]
    
    for placeholder, patterns in token_patterns:
        for pat in patterns:
            # We match and replace the pattern
            if placeholder == '%1%':
                regex_pat = r'\s*x\s*p\s*t\s*o\s*n\s*e\s*p\s*e\s*r\s*c\s*e\s*n\s*t\s*'
            else:
                regex_pat = r'\s*x\s*p\s*t\s*' + pat[3:] + r'\s*'
            restored = re.sub(regex_pat, f" {placeholder} ", restored, flags=re.IGNORECASE)
            
    restored = re.sub(r'\s+', ' ', restored).strip()
    
    # Verify count of placeholders matches original
    for placeholder, _ in placeholder_list:
        orig_count = text.count(placeholder)
        restored_count = restored.count(placeholder)
        if orig_count != restored_count:
            # Fallback to direct translation without tokens if count mismatch
            url_fallback = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source_lang}&tl={target_lang}&dt=t&q={urllib.parse.quote(text)}"
            req_fallback = urllib.request.Request(
                url_fallback, 
                headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
            )
            try:
                with urllib.request.urlopen(req_fallback) as response:
                    data = json.loads(response.read().decode('utf-8'))
                    restored = "".join([segment[0] for segment in data[0] if segment[0]])
            except Exception:
                pass
            break
            
    return restored

def parse_pot(pot_path):
    entries = []
    current_entry = {
        'comments': [],
        'msgctxt': None,
        'msgid': [],
        'msgstr': []
    }
    
    with open(pot_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    state = None
    for line in lines:
        line_strip = line.strip()
        if not line_strip:
            if current_entry['msgid']:
                entries.append(current_entry)
                current_entry = {
                    'comments': [],
                    'msgctxt': None,
                    'msgid': [],
                    'msgstr': []
                }
            state = None
            continue
            
        if line.startswith('#'):
            current_entry['comments'].append(line.rstrip('\n'))
        elif line.startswith('msgctxt '):
            state = 'msgctxt'
            current_entry['msgctxt'] = [line.split('msgctxt ', 1)[1].strip()]
        elif line.startswith('msgid '):
            state = 'msgid'
            current_entry['msgid'].append(line.split('msgid ', 1)[1].strip())
        elif line.startswith('msgstr '):
            state = 'msgstr'
            current_entry['msgstr'].append(line.split('msgstr ', 1)[1].strip())
        elif line.startswith('"') and line_strip.endswith('"'):
            if state == 'msgctxt':
                current_entry['msgctxt'].append(line_strip)
            elif state == 'msgid':
                current_entry['msgid'].append(line_strip)
            elif state == 'msgstr':
                current_entry['msgstr'].append(line_strip)
                
    if current_entry['msgid']:
        entries.append(current_entry)
        
    return entries

def parse_quoted_strings(lines):
    full_str = ""
    for line in lines:
        try:
            full_str += json.loads(line)
        except Exception:
            if line.startswith('"') and line.endswith('"'):
                s = line[1:-1]
                s = s.replace('\\n', '\n').replace('\\t', '\t').replace('\\"', '"').replace('\\\\', '\\')
                full_str += s
            else:
                full_str += line
    return full_str

def escape_to_quoted(s):
    escaped = s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
    return f'"{escaped}"'

def entry_to_str(entry, translated_str):
    lines = []
    lines.extend(entry['comments'])
    if entry['msgctxt']:
        lines.append("msgctxt " + " ".join(entry['msgctxt']))
    lines.append("msgid " + " ".join(entry['msgid']))
    lines.append("msgstr " + escape_to_quoted(translated_str))
    return "\n".join(lines)

def update_metadata_json(meta_path, translations):
    with open(meta_path, 'r', encoding='utf-8') as f:
        meta = json.load(f)
        
    kplugin = meta.get('KPlugin', {})
    
    # Filter out old Name and Description translations
    keys_to_delete = []
    for k in kplugin.keys():
        if k.startswith('Name[') or k.startswith('Description['):
            keys_to_delete.append(k)
    for k in keys_to_delete:
        del kplugin[k]
        
    # Re-add Name=FitDash in all languages
    # Re-add translated descriptions
    for lang in sorted(translations.keys()):
        # French, German, Spanish, Dutch might be in PO but let's make sure they are in metadata as well
        kplugin[f'Name[{lang}]'] = "FitDash"
        kplugin[f'Description[{lang}]'] = translations[lang]
        
    with open(meta_path, 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=4, ensure_ascii=False)
    print("Updated metadata.json")

def update_desktop_file(file_path, translations):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    filtered = []
    for line in lines:
        if line.startswith('Name[') or line.startswith('Comment['):
            continue
        filtered.append(line)
        
    final = []
    for line in filtered:
        final.append(line)
        if line.strip() == "Name=FitDash":
            for lang in sorted(translations.keys()):
                final.append(f"Name[{lang}]=FitDash\n")
        elif line.strip() == "Comment=Fitbit step counter and fitness data widget for KDE Plasma":
            for lang, comment in sorted(translations.items()):
                final.append(f"Comment[{lang}]={comment}\n")
                
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(final)
    print(f"Updated {file_path}")

def main():
    project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pot_path = os.path.join(project_dir, 'po', 'plasma_applet_com.democe.fitdash.pot')
    po_dir = os.path.join(project_dir, 'po')
    
    print("Parsing POT file...")
    pot_entries = parse_pot(pot_path)
    
    # Store description translations to update metadata files at the end
    description_translations = {}
    
    # First, let's translate the description to all languages
    print("Translating application descriptions...")
    for locale, info in sorted(LOCALES.items()):
        gt_code = info['gt']
        translated_desc = translate(DESCRIPTION_SRC, gt_code)
        description_translations[locale] = translated_desc
        print(f"  {locale}: {translated_desc}")
        
    # Process each locale
    for locale, info in sorted(LOCALES.items()):
        po_path = os.path.join(po_dir, f"{locale}.po")
        
        # If PO file already exists, let's parse it and read the translated strings, or skip translation
        # Wait, if we already wrote po/it.po, ko.po, etc., let's make sure we preserve them
        if os.path.exists(po_path):
            print(f"PO file for {locale} already exists. Skipping PO translation (keeping existing).")
            continue
            
        print(f"Translating PO file for {locale} ({info['name']})...")
        gt_code = info['gt']
        
        po_lines = []
        
        # Header translation entry
        header_text = (
            'msgid ""\n'
            'msgstr ""\n'
            f'"Project-Id-Version: FitDash 1.0.5\\n"\n'
            f'"Report-Msgid-Bugs-To: democe@outlook.com\\n"\n'
            f'"POT-Creation-Date: 2026-06-28 18:35-0600\\n"\n'
            f'"PO-Revision-Date: 2026-06-29 00:00+0000\\n"\n'
            f'"Last-Translator: FitDash contributors\\n"\n'
            f'"Language-Team: {info["name"]}\\n"\n'
            f'"Language: {locale}\\n"\n'
            f'"MIME-Version: 1.0\\n"\n'
            f'"Content-Type: text/plain; charset=UTF-8\\n"\n'
            f'"Content-Transfer-Encoding: 8bit\\n"\n'
        )
        po_lines.append(header_text)
        
        # Translate each entry (skipping the empty header msgid)
        for entry in pot_entries:
            msgid_val = parse_quoted_strings(entry['msgid'])
            if not msgid_val:
                continue
                
            translated = translate(msgid_val, gt_code)
            # Throttle a tiny bit to avoid hitting rate limits
            time.sleep(0.1)
            
            entry_str = entry_to_str(entry, translated)
            po_lines.append(entry_str)
            
        # Write to .po file
        with open(po_path, 'w', encoding='utf-8') as f:
            f.write("\n".join(po_lines) + "\n")
            
        print(f"  Created {locale}.po successfully.")
        # Extra delay between files
        time.sleep(1.0)
        
    # Update metadata files
    update_metadata_json(os.path.join(project_dir, 'package', 'metadata.json'), description_translations)
    update_desktop_file(os.path.join(project_dir, 'package', 'metadata.desktop'), description_translations)
    update_desktop_file(os.path.join(project_dir, 'scripts', 'com.democe.fitdash.desktop'), description_translations)
    
    print("All translation and metadata updates complete!")

if __name__ == "__main__":
    main()
