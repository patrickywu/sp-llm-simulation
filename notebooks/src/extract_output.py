import json
import os
import re

# Logical Flow: normalize any text used (lowercase and replace weird unicoding) then create an extract repsonse function that will search for the specified format of answer choice then comma (in this case I am also included other punctuation marks)
# it also finds refusals using key phrases then for the final extract these functions are used and other main variables are stored and organized as well.

# normalize text to lowercase and response the OpenAI ' and - cases
def normalize_text(text):
        if text is None:
            return ""
        text = str(text)
        text = text.replace("\u2019", "'").replace("\u2018", "'")
        text = text.replace("\u2013", "-").replace("\u2014", "-")
        text = text.lower()
        text = text.replace(",", "")
        text = " ".join(text.split())
        return text

def single_option_fallback(output_norm, opt_norm):
    mentioned = set()

    for norm, original in opt_norm:
        # added some common punctuation 
        pattern = (
            r"(?:^|[\s\(\[\{<\"'])" + re.escape(norm) + r"(?:$|[\s\)\]\}>\"',\.\!?:;])"
)
        if re.search(pattern, output_norm):
            mentioned.add(original)

        if len(mentioned) > 1:
            return None

    if len(mentioned) == 1:
        return mentioned.pop()

    return None



def extract_response(output_text, response_options):

    # remove chain-of-thought for results
    output_clean = re.sub(r"<think>.*?</think>", "", output_text, flags=re.DOTALL | re.IGNORECASE)
    output_clean = re.sub(r"(\*\*|\*|__|_)", "", output_clean)

    output_norm_1 = normalize_text(output_clean)
    output_norm_1 = output_norm_1.replace(
    "high priority but not the highest", 
    "high priority but not the highest priority"
)

    # normalize options
    opt_norm = [(normalize_text(opt), opt.lower()) for opt in response_options]
    opt_norm.sort(key=lambda x: -len(x[0]))  # longest first to avoid misclass

    # extract output in format (accounting for other punctuation)
    for norm, original in opt_norm:
        pattern = (
            r"(?:^|[\s\(\[\{<\"'])"
            + re.escape(norm)
            + r"(?:$|[\s\)\]\}>\"',\.\!?:;,-])"
        )
        if re.search(pattern, output_norm_1):
            return original

    
    fallback = single_option_fallback(output_norm_1, opt_norm)
    if fallback:
        return fallback
    
    refusal_phrases = [
        "im not able to",
        "im unable to",
        "cannot provide an answer",
        "i can't",
        "i cannot"
    ]
    for phrase in refusal_phrases:
        if phrase in output_norm_1:
            return "refusal"

    return "not extracted"


def extract(json_path):
    # open JSON
    with open(json_path, "r") as f:
        data = json.load(f)

    #store demographic keys
    demo_keys = ["race_or_ethnicity", "gender", "age", "education", "income", "party"]

    for entry in data:
        # extract output
        output = entry.get("output", "")

        if isinstance(output, dict):
            output = output.get("text", "") # get the text part from the dictionary
        elif isinstance(output, list):
            output = " ".join([item.get("text", "") if isinstance(item, dict) else str(item) for item in output])
        else:
            output = str(output) # just in case

        # extract response
        response_options = entry.get("response_options", [])
        entry["extracted_option"] = extract_response(output, response_options)


        if "demographics" not in entry or not isinstance(entry["demographics"], dict):
            entry["demographics"] = {}

        for key in demo_keys:
            if key not in entry["demographics"] or entry["demographics"][key] is None:
                entry["demographics"][key] = "NaN" # NaN logic discussed in meeting

    # for saving analyzed JSON
    directory, filename = os.path.split(json_path)
    analyzed_filename = filename.replace("raw_", "analyzed_")
    analyzed_path = os.path.join(directory, analyzed_filename)

    with open(analyzed_path, "w") as f:
        json.dump(data, f, indent=4)

    return analyzed_path