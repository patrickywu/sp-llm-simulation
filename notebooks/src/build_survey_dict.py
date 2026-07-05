import pandas as pd

def build_survey_dict(excel_path, sheet_name="demographics_long_format"):
    df = pd.read_excel(excel_path, sheet_name=sheet_name)

    survey_dict = {}

    # Group data by poll name (so each are separate dictionary entry)
    for poll_name, group_df in df.groupby('Poll name', sort=False):
        question_text = group_df['Question'].iloc[0]
        response_options_raw = group_df['Response options'].iloc[0]
        response_options = [opt.strip() for opt in str(response_options_raw).split(",")] if response_options_raw else []

        demographics = {}

        # Group again within each poll by demographic group
        for demo_group, demo_df in group_df.groupby("Group", sort=False):
            key = str(demo_group).lower().strip() # normalize
            options = demo_df["Subgroup"].tolist()
            stats = [f"{s}%" if pd.notna(s) else None for s in demo_df["%"].tolist()] # collect population percentages (for anlayses)

            # skip empty demographic group
            if all(s is None for s in stats):
                continue

            demographics[key] = {"options": options, "stats": stats}

        # store results (questions, response_options, demographics)
        survey_dict[poll_name] = {
            "question": question_text,
            "response_options": response_options,
            "demographics": demographics
        }

    return survey_dict
