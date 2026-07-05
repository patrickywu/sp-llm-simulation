import re
import itertools

class LlmSurveyParser:
    def __init__(self, dictionary, subgroups="false", embody="false"):
        self.dictionary = dictionary
        self.titles = []
        self.values = []
        self.questions = []
        self.response_options = []
        self.demographics = []
        self.demographics_options = []
        self.demographics_stats = []
        self.combinations = []
        self.prompts = []
        self.prompt_records = [] 
        self.subgroups = subgroups
        self.embody = embody  # persona or non persona prmpts

    ## Extracting title, question, response options, and demographics
    def get_metadata(self):
        self.titles = list(self.dictionary.keys())
        self.questions = [self.dictionary[title]["question"] for title in self.titles]
        self.response_options = [self.dictionary[title]["response_options"] for title in self.titles]
        self.demographics = [list(self.dictionary[t]["demographics"].keys()) for t in self.titles]

    ## Use standardized demographic options for all surveys
    def get_demographics(self):
        for title in self.titles:
            entry = self.dictionary[title]["demographics"]
            survey_options = []
            survey_stats = []

            for key in entry.keys():
                options = entry[key]["options"] 
                stats = entry[key]["stats"]
                survey_options.append(options)
                survey_stats.append(stats)

            self.demographics_options.append(survey_options)
            self.demographics_stats.append(survey_stats)

    # Generate all combinations of demographics
    def get_combinations(self):
        for op in self.demographics_options:
            self.combinations.append(list(itertools.product(*op)))

    # --- PROMPT GENERATION ---
    def generate_prompt(self):
        for demographics_index in range(len(self.demographics)):
            question = self.questions[demographics_index]
            response_options = self.response_options[demographics_index]
            combinations = self.combinations[demographics_index]
            title = self.titles[demographics_index]
            demo_keys = list(self.dictionary[title]["demographics"].keys())

            filler_phrases = {
                "race_or_ethnicity": "{}",
                "gender": "identifying as {} for gender",
                "age": "aged {}",
                "party": "identifying as a {} voter",
                "education": "{}",
                "income": "earning {}"
            }

            # --- SUBGROUP PROMPTS ---
            if self.subgroups == "true":
                for combo in combinations:
                    prompt = []

                    # Build demographic sentence
                    demo_sentence_parts = []
                    for i, key in enumerate(demo_keys):
                        phrase = filler_phrases.get(key, "{}")
                        value = combo[i]
                        if key == "party" and value.lower() == "independent":
                            phrase = "identifying as an {} voter"
                        demo_sentence_parts.append(phrase.format(value))

                    demo_sentence = ", ".join(demo_sentence_parts)

                    if self.embody == "true":
                        prompt.append("You are a " + demo_sentence + ", living in the U.S.")
                        prompt.append(f"Answer the following question: {question}")
                        prompt.append("Response options:")
                        options_text = ", ".join(response_options[:-1]) + f", or {response_options[-1]}"
                        prompt.append(f"[{options_text}].")
                        prompt.append("Please choose from the options provided and then give a brief reason why. The format should be: {selected response option}, followed by brief reasoning for the selection.")
                    else:
                        prompt.append("You are a public opinion specialist. How would a person with the following demographic information answer the survey question below?")
                        prompt.append("You are a " + demo_sentence + ", living in the U.S.")
                        prompt.append(f"Answer the following question: {question}")
                        prompt.append("Response options:")
                        options_text = ", ".join(response_options[:-1]) + f", or {response_options[-1]}."
                        prompt.append(f"[{options_text}]")
                        prompt.append("Please choose from the options provided and then give a very brief reason why.  The format should be: {selected option}, brief reasoning.")

                    full_prompt = re.sub(r'\s+', ' ', ' '.join(prompt)).strip()
                    self.prompts.append(full_prompt)

                    # --- STORE RECORD ---
                    self.prompt_records.append({
                        "title": title,
                        "question": question,
                        "prompt": full_prompt,
                        "response_options": response_options,
                        "demographics": dict(zip(demo_keys, combo)),
                        "embody": self.embody
                    })

            # --- NON-SUBGROUP PROMPTS ---
            else:
                prompt = []
                prompt.append("You are a public opinion expert. You are presented with a survey question asking how a US citizen would respond with one of the following responses.")
                prompt.append(f"The question you are answering is: {question}")
                prompt.append("Select a response option from the following:")
                options_text = ", ".join(response_options[:-1]) + f", or {response_options[-1]}."
                prompt.append(f"[{options_text}]")
                prompt.append("Please choose from the options provided and then give a very brief reason why.  The format should be: {selected option}, brief reasoning.")

                full_prompt = re.sub(r'\s+', ' ', ' '.join(prompt)).strip()
                self.prompts.append(full_prompt)

                # --- STORE RECORD (no demographics) ---
                demographics_nan = {key: "NaN" for key in ["race_or_ethnicity", "gender", "age", "education", "income", "party"]}
    

                self.prompt_records.append({
                    "title": title,
                    "question": question,
                    "prompt": full_prompt,
                    "demographics": demographics_nan,
                    "response_options": response_options,
                    "embody": self.embody
                })

    # change formatting to return all information necessary (using append)
    def convert_format(self):
        formatted = []
        for record in self.prompt_records:
            formatted.append({
                "title": record["title"],
                "question": record["question"],
                "demographics": record["demographics"],
                "embody": record["embody"],
                "prompt": [{"role": "user", "content": record["prompt"]}],
                "response_options": record["response_options"]
            })
        return formatted
    

    # function to extract ONLY text responsese for simple prompting
    def get_prompt_texts(self):
        return [[{"role": "user", "content": record["prompt"]}] for record in self.prompt_records]


    # Full pipeline
    def run_all(self, subgroups=None, embody=None):
        if subgroups is not None:
            self.subgroups = subgroups
        if embody is not None:
            self.embody = embody

        self.get_metadata()
        self.get_demographics()
        self.get_combinations()
        self.generate_prompt()
        print(f"Generated {len(self.prompts)} prompts.")
        return self.convert_format()
