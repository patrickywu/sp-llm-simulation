# "Simulating Social Attitudes with LLMs: Accuracy, Demographic Effects, and Refusal Behavior in the Sensitive Domain of Suicide Prevention"

**Authors**: Cristina J. Perez, Michael P. Vasquez Jr, Philippe Giabbanelli, Patrick Y. Wu

## Project Overview

This repository contains the data, code, and analyses used to evaluate LLM responses to survey questions and compare them with real-world survey results (ground truth). It includes the survey sources, processed ground truth data, model outputs, analysis notebooks for the research questions (RQ1–RQ3), and scripts used throughout the prompting and analysis pipeline. The repository is organized to document the full workflow—from survey collection and prompting validation to final model runs and statistical analysis.

## Notebook Contents

- S1 Survey Data - contains all the research and information collected from the surveys we collected questions from
- S2 Ground Truth Data - contains the ground truth collected from the surveys for analyses
- results_csv.zip - zip file containing 3 csv files:
    1. ground_truth_tidy -> csv form of the ground truth excel
    2. LLM_analysis_ordinal -> results excluding those that do not have ground truth (surveys included: 28, see research design for notes on this)
    3. LLM_combined_results -> full results included those without ground truth (used for refusal analysis)

**notebooks**:

- 00_preliminary_testing - contains code_validation that validate the prompting pipeline and extract output functions we created
- 01_final_prompting - contains the prompting notebook, and the file to create the result csv files
- 02_analyses - contains analyses for RQ1-3
- src - contains all source code files.

## Citation

```bibtex
@inproceedings{perez-etal-2026-simulating,
    title = "Simulating Social Attitudes with {LLM}s: Accuracy, Demographic Effects, and Refusal Behavior in the Sensitive Domain of Suicide Prevention",
    author = "Perez, Cristina J.  and
      Jr, Michael P. Vasquez  and
      Giabbanelli, Philippe  and
      Wu, Patrick Y.",
    editor = "Card, Dallas  and
      Field, Anjalie  and
      Keith, Katherine  and
      Mendelsohn, Julia",
    booktitle = "Proceedings of the Seventh Workshop on Natural Language Processing and Computational Social Science",
    month = jul,
    year = "2026",
    address = "San Diego",
    publisher = "Association for Computational Linguistics",
    url = "https://aclanthology.org/2026.nlpcss-1.12/",
    doi = "10.18653/v1/2026.nlpcss-1.12",
    pages = "176--189",
    ISBN = "979-8-89176-426-2",
    abstract = "Large language models (LLMs) are increasingly used to simulate public opinion, yet their validity in sensitive policy domains remains underexplored. We evaluate whether LLMs can reproduce attitudes toward suicide prevention policies using 32 questions drawn from seven nationally representative U.S. surveys (2023-2025). We systematically vary demographic conditioning (race/ethnicity, gender, age, education, income, party), prompt framing (direct elicitation, respondent embodiment, specialist embodiment), and model architecture (GPT-5 Nano, DeepSeek V3.2, Meta Llama 3.1 8B, Mistral Small 24B). Across 811,560 prompts, the mean absolute error{---}the average gap between predicted and human response distributions{---}is 23 percentage points. We also find that LLM responses to demographic-conditioned prompts diverge substantially from prompts without demographic information. In short, what distribution LLMs draw on when generating responses to sensitive polling questions remains unclear. Model choice matters more than framing for accuracy, whereas refusal behavior varies sharply across models and prompt designs. Our findings highlight the limitations of LLMs for social simulation in the context of sensitive topics."
}
```
