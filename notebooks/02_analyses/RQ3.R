############################
# LOAD PACKAGES
############################

library(dplyr)
library(readr)

############################
# LOAD DATA
############################

# Read combined LLM results dataset
llm_df <- read_csv("LLM_combined_results.csv")

# check total observations (prompts)
nrow(llm_df) # should be 811,560 <- see notebooks/00_preliminary_testing_validation/code_validation/check_result_counts.ipynb for validated total

# rechecking numbers align with expectation <- see see notebooks/00_preliminary_testing_validation/code_validation/check_result_counts.ipynb for additional confirmation
survey_counts <- llm_df %>%
  group_by(poll_name, prompt_frame) %>%
  summarise(n_prompts = n(), .groups = "drop") %>%
  arrange(poll_name, prompt_frame)

survey_table <- survey_counts %>%
  tidyr::pivot_wider(
    names_from = prompt_frame,
    values_from = n_prompts
  ) %>%
  mutate(total = direct + embody + specialist)

# print(survey_table, n = 35) omitted for visual effectiveness (matches expected)

############################
# CHECK REFUSAL VARIABLE
############################

# Confirm refusal is coded as 0 (response) or 1 (refusal)
table(llm_df$refusal)

############################
# OVERALL REFUSAL RATE
############################

# Count total prompts actually recorded
total_prompts <- nrow(llm_df)

# Count total refusals
total_refusals <- sum(llm_df$refusal, na.rm = TRUE)

# Compute refusal percentage
overall_refusal_percent <- 100 * total_refusals / total_prompts

cat("Total prompts:", total_prompts, "\n")
cat("Total refusals:", total_refusals, "\n")
cat("Overall refusal rate:", round(overall_refusal_percent, 2), "%\n\n")

############################
# REFUSAL RATE BY MODEL
############################

# Calculate refusal rate separately for each model
refusal_by_model <- llm_df %>%
  group_by(model) %>%
  summarise(
    total_prompts = n(),                        # prompts sent to this model
    total_refusals = sum(refusal, na.rm = TRUE),# refusals returned
    refusal_percent = 100 * total_refusals / total_prompts,
    .groups = "drop"
  ) %>%
  arrange(desc(refusal_percent))

cat("Refusals by model:\n")
print(refusal_by_model)

###########################################
# REFUSAL RATE BY MODEL AND PROMPT FRAMING
###########################################

# Evaluate how prompt framing affects refusal behavior
refusal_by_model_frame <- llm_df %>%
  group_by(model, prompt_frame) %>%
  summarise(
    total_prompts = n(),
    total_refusals = sum(refusal, na.rm = TRUE),
    refusal_percent = 100 * total_refusals / total_prompts,
    .groups = "drop"
  ) %>%
  arrange(desc(refusal_percent))

cat("\nRefusals by model and prompt framing:\n")
print(refusal_by_model_frame)

######################################
# REFUSAL RATE BY PROMPT FRAME (TOTAL)
######################################

# Aggregate refusal behavior across models to compare framing strategies
refusal_by_frame <- llm_df %>%
  group_by(prompt_frame) %>%
  summarise(
    total_prompts = n(),
    total_refusals = sum(refusal, na.rm = TRUE),
    refusal_percent = 100 * total_refusals / total_prompts,
    .groups = "drop"
  ) %>%
  arrange(desc(refusal_percent))

cat("\nRefusals by prompt frame:\n")
print(refusal_by_frame)