import pandas as pd
import os

# function takes prompts, outputs, model_type, iteration number, and file_path and orders them how i specified

def clean_unicode(text):
    if text is None:
        return None

    text = str(text)
    return (
        text
        .replace("\u2019", "'")
        .replace("\u2018", "'")
        .replace("\u201c", '"')
        .replace("\u201d", '"')
        .replace("\u2013", "-")
        .replace("\u2014", "-")
        .replace("\u00a0", " ")
    )

def save_survey_results(prompt_records, outputs, model_type, iteration, file_path, reason_effort):
    all_rows = []

    for i, record in enumerate(prompt_records):
        raw_output = outputs[i] if i < len(outputs) else None
        clean_output = clean_unicode(raw_output)

        row = {
            "iteration": iteration,
            "model_type": model_type,
            "reason_effort": reason_effort,
            "poll_name": record.get("title"),
            "original_question": clean_unicode(record.get("question")),
            "demographics": record.get("demographics"),
            "embody": record.get("embody"),
            "prompt": clean_unicode(record.get("prompt")),
            "output": clean_output,
            "response_options": record.get("response_options")
        }

        all_rows.append(row)

    df_new = pd.DataFrame(all_rows)

    # append if already exists (for multiple iterations)
    if os.path.exists(file_path):
        df_existing = pd.read_json(file_path)
        df_new = pd.concat([df_existing, df_new], ignore_index=True)

    # to_json function using pandas
    df_new.to_json(file_path, orient="records", indent=4)
    print(f"Saved {len(all_rows)} rows to {file_path} as JSON")
