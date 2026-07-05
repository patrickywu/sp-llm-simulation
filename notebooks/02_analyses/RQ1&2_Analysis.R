############
# PACKAGES
############

library(dplyr)
library(readr)
library(readxl)
library(tidyr)
library(stringr)
library(ggplot2)
library(broom)
library(lme4)
library(purrr)

############
# LOAD DATA
############

llm_df <- read_csv("LLM_analysis_ordinal.csv")
ground_truth <- read_csv("ground_truth_tidy.csv")

dim(llm_df)

################
# DATA CLEANING
################

# Polls where ground truth combines response options 6 & 7
combine_polls <- c(
  "Science_Direct_suicide_help_Q1",
  "Science_Direct_suicide_help_Q2",
  "Science_Direct_suicide_help_Q3",
  "Science_Direct_suicide_help_Q4",
  "Science_Direct_suicide_help_Q5"
)

# Pivot demographics long so each row = one observation per demographic dimension.

results_long <- llm_df %>%
  filter(refusal == 0) %>%
  pivot_longer(
    cols = c(race, gender, age, education, income, party),
    names_to = "subgroup_type", values_to = "subgroup"
  ) %>%
  filter(!is.na(subgroup), subgroup != "NaN") %>%
  mutate(
    subgroup_type = str_to_lower(str_trim(subgroup_type)),
    subgroup = str_to_lower(str_trim(subgroup)),
    response_option = str_to_lower(str_trim(extracted_option)),
    # Combine response options 6 & 7 for Science Direct
    response_option = case_when(
      poll_name %in% combine_polls & response_option %in% c("6", "7") ~ "6_&_7_combined",
      TRUE ~ response_option
    ),
    response_option = str_replace_all(response_option, "\u2019", "'"),
    response_option = str_replace_all(response_option, "\n", " "),
    response_option = str_trim(response_option)
  )

cat("\nSurveys after cleaning:", length(unique(results_long$poll_name)), "\n")

results_long_direct <- llm_df %>%
  filter(refusal == 0, prompt_frame == "direct") %>%
  mutate(
    response_option = str_to_lower(str_trim(extracted_option)),
    response_option = case_when(
      poll_name %in% combine_polls & response_option %in% c("6", "7") ~ "6_&_7_combined",
      TRUE ~ response_option
    ),
    response_option = str_replace_all(response_option, "\u2019", "'"),
    response_option = str_replace_all(response_option, "\n", " "),
    response_option = str_trim(response_option)
  )

cat("\nSurveys after cleaning:", length(unique(results_long_direct$poll_name)), "\n")

##########################
# CLEAN GROUND TRUTH
##########################

ground_truth_clean <- ground_truth %>%
  mutate(
    subgroup_type = str_to_lower(str_trim(subgroup_type)),
    subgroup = str_to_lower(str_trim(subgroup)),
    response_option = str_remove(response_option, "_aor"),
    response_option = str_replace_all(response_option, "\n", " "),
    response_option = str_replace_all(response_option, "\u2019", "'"),
    response_option = str_trim(response_option),
    response_option = str_to_lower(response_option),
    response_option_combined = case_when(
      poll_name %in% combine_polls & response_option %in% c("6", "7") ~ "6_&_7_combined",
      TRUE ~ response_option
    )
  ) %>%
  filter(!is.na(percent)) %>%
  distinct(poll_name, subgroup_type, subgroup, response_option_combined, .keep_all = TRUE) %>%
  group_by(poll_name, subgroup_type, subgroup, response_option_combined) %>%
  summarise(
    percent = if_else(response_option_combined == "6_&_7_combined", first(percent), sum(percent)),
    .groups = "drop"
  )

cat("Surveys with ground truth:", length(unique(ground_truth_clean$poll_name)), "\n")

##########################
# GROUND TRUTH PROPORTIONS
##########################

# Normalize ground truth percentages to proportions that sum to 1.
# Flag subgroups with full vs partial distributions.

gt_props <- ground_truth_clean %>%
  group_by(poll_name, subgroup_type, subgroup) %>%
  mutate(
    gt_total = sum(percent),
    gt_prop = percent / gt_total,
    n_options_gt = n(),
    has_full_dist = gt_total >= 90  # Only for diagnostic purposes, not actually used
  ) %>%
  ungroup()

cat("\nSubgroups with full distributions:",
    gt_props %>% filter(has_full_dist) %>% distinct(poll_name, subgroup_type, subgroup) %>% nrow(),
    "\n")
cat("Subgroups with partial distributions:",
    gt_props %>% filter(!has_full_dist) %>% distinct(poll_name, subgroup_type, subgroup) %>% nrow(),
    "\n")

####################################
# LLM RESPONSE PROPORTIONS
####################################

llm_props <- results_long %>%
  group_by(model, prompt_frame, poll_name,
           subgroup_type, subgroup, response_option) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(model, prompt_frame, poll_name,
           subgroup_type, subgroup) %>%
  mutate(llm_prop = n / sum(n)) %>%
  ungroup()

####################################
# DIRECT (NO PERSONA) PROPORTIONS
####################################

direct_props <- results_long_direct %>%
  group_by(model, poll_name, response_option) %>%
  summarise(n_direct = n(), .groups = "drop") %>%
  group_by(model, poll_name) %>%
  mutate(direct_prop = n_direct / sum(n_direct)) %>%
  ungroup()

####################################
# PROPORTION DIFFERENCE: DEMOGRAPHIC vs DIRECT
####################################

# Keep only non-direct prompt frames from llm_props for the comparison
prop_diff <- llm_props %>%
  filter(prompt_frame != "direct") %>%
  left_join(
    direct_props %>% select(model, poll_name, response_option, direct_prop),
    by = c("model", "poll_name", "response_option")
  ) %>%
  mutate(
    direct_prop = replace_na(direct_prop, 0),
    prop_diff = llm_prop - direct_prop
  )

####################################
# JOIN LLM AND GROUND TRUTH
####################################


joined <- llm_props %>%
  full_join(
    gt_props,
    by = c("poll_name", "subgroup_type", "subgroup",
           "response_option" = "response_option_combined")
  ) %>%
  mutate(
    llm_prop = replace_na(llm_prop, 0),
    gt_prop  = replace_na(gt_prop, 0)
  )

####################################
# DISTRIBUTIONAL DISTANCE METRICS
####################################

# MAE: Mean Absolute Error
# TVD: Total Variation Distance (0 = perfect match, 1 = no overlap)
# JSD: Jensen-Shannon Divergence (symmetric, bounded [0, 1] with log2)

distance_df <- joined %>%
  filter(!is.na(model)) %>%  # drop GT-only rows with no LLM match
  group_by(model, prompt_frame, poll_name,
           subgroup_type, subgroup) %>%
  summarise(
    n_options_gt = sum(gt_prop > 0),
    n_options_llm = sum(llm_prop > 0),

    # Mean Absolute Error
    mae = mean(abs(llm_prop - gt_prop)),
        
    # Total Variation Distance
    tvd = 0.5 * sum(abs(llm_prop - gt_prop)),
    
    # Jensen-Shannon Divergence
    jsd = {
      p <- llm_prop
      q <- gt_prop
      m <- (p + q) / 2
      kl <- function(a, b) sum(ifelse(a == 0, 0, a * log2(a / b)))
      0.5 * kl(p, m) + 0.5 * kl(q, m)
    },
    
    .groups = "drop"
  )

# Restrict to subgroups with full ground truth distributions
distance_full <- distance_df %>%
  filter(n_options_gt >= 2)

cat("\nTotal comparisons (full distributions):", nrow(distance_full), "\n")

####################################
# RQ1: OVERALL ACCURACY
####################################

rq1_summary_mae <- distance_full %>%
  summarise(
    mean_mae = mean(mae),
    sd_mae   = sd(mae),
    median_mae = median(mae),
    q25_mae  = quantile(mae, 0.25),
    q75_mae  = quantile(mae, 0.75),
    n = n()
  )

rq1_summary_tvd <- distance_full %>%
  summarise(
    mean_tvd = mean(tvd),
    sd_tvd   = sd(tvd),
    median_tvd = median(tvd),
    q25_tvd  = quantile(tvd, 0.25),
    q75_tvd  = quantile(tvd, 0.75),
    n = n()
  )

rq1_summary_jsd <- distance_full %>%
  summarise(
    mean_jsd = mean(jsd),
    sd_jsd   = sd(jsd),
    median_jsd = median(jsd),
    q25_jsd  = quantile(jsd, 0.25),
    q75_jsd  = quantile(jsd, 0.75),
    n = n()
  )

cat("\n=== RQ1: Overall Accuracy ===\n")
print(rq1_summary_mae)
print(rq1_summary_tvd)
print(rq1_summary_jsd)

# By subgroup type
rq1_by_subgroup <- distance_full %>%
  group_by(subgroup_type) %>%
  summarise(
    mean_mae = mean(mae),
    sd_mae = sd(mae),
    mean_tvd = mean(tvd),
    sd_tvd   = sd(tvd),
    mean_jsd = mean(jsd),
    sd_jsd   = sd(jsd),
    n = n(),
    .groups = "drop"
  )

cat("\n=== RQ1: Accuracy by Demographic Dimension ===\n")
print(rq1_by_subgroup)

# By subgroup type and model
rq1_by_subgroup_model <- distance_full %>%
  group_by(subgroup_type, model) %>%
  summarise(
    mean_mae   = mean(mae),
    sd_mae     = sd(mae),
    median_mae = median(mae),
    q25_mae    = quantile(mae, 0.25),
    q75_mae    = quantile(mae, 0.75),
    n = n(),
    .groups = "drop"
  )

cat("\n=== RQ1: MAE by Demographic Dimension x Model ===\n")
print(rq1_by_subgroup_model)

####################################
# RQ1: ACCURACY PLOTS
####################################

# Combined distribution: MAE, TVD, and JSD overall
distance_long <- distance_full %>%
  select(mae, tvd, jsd) %>%
  pivot_longer(cols = everything(), names_to = "metric", values_to = "value") %>%
  mutate(metric = factor(metric,
    levels = c("mae", "tvd", "jsd"),
    labels = c("MAE", "TVD", "JSD")
  ))

ggplot(distance_long, aes(x = value, fill = metric)) +
  geom_histogram(bins = 30, color = "white") +
  facet_wrap(~ metric, scales = "free_x") +
  scale_fill_manual(values = c("MAE" = "coral", "TVD" = "steelblue", "JSD" = "#7CAE00")) +
  labs(
    x = "Value",
    y = "Number of subgroup response rows"
  ) +
  theme_minimal(base_size=2) +
  theme(    
    legend.position = "none",
    strip.text = element_text(size=6),
    axis.title = element_text(size=6),
    axis.text = element_text(size=4)
  )

ggsave("similarity_metrics.pdf", width = 800, height = 600, units = "px", dpi = 300)

# MAE by model
model_labels <- setNames(
  paste0("(", letters[seq_along(unique(distance_full$model))], ")"),
  sort(unique(distance_full$model))
)

model_display <- c(
  "DeepSeek"   = "DeepSeek",
  "GPT-5 Nano" = "GPT-5 Nano",
  "Meta-Llama" = "Meta Llama",
  "mistralai"  = "Mistral"
)

model_text <- distance_full %>%
  distinct(model) %>%
  arrange(model) %>%
  mutate(
    display = coalesce(model_display[model], model),
    label   = paste0("(", letters[row_number()], ")\n", display)
  )

p <- ggplot(distance_full, aes(x = mae)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "white") +
  geom_text(
    data = model_text,
    aes(label = label),
    x = Inf, y = Inf, hjust = 1.1, vjust = 1.3,
    size = 2.5, fontface = "bold", inherit.aes = FALSE
  ) +
  facet_wrap(~ model) +
  labs(
    x = "Mean absolute error (|LLM % - Ground Truth %|)",
    y = "Number of subgroup response rows"
  ) +
  theme_minimal(base_size=2) +
  theme(
    strip.text = element_blank(),
    strip.background = element_blank(),
    panel.grid.minor = element_blank(),
    axis.title = element_text(size=6),
    axis.text = element_text(size=4)
  )

ggsave("errorModels.pdf", width = 800, height = 600, units = "px", dpi = 300)

####################################
# RQ1: MODAL DIRECT BASELINE
####################################

# Identify the modal direct response per model x poll
direct_mode <- results_long_direct %>%
  count(model, poll_name, response_option) %>%
  group_by(model, poll_name) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(model, poll_name, direct_mode = response_option)

####################################
# RQ1: PROPORTION ON DIRECT MODE
####################################

# For each demographic subgroup, compute what fraction of persona responses
# matched the LLM's modal (most common) direct answer.
# 1.0 = persona always agreed with the direct mode
# 0.0 = persona never chose the direct mode

demo_vs_direct_mode <- llm_props %>%
  filter(prompt_frame != "direct") %>%
  inner_join(direct_mode, by = c("model", "poll_name")) %>%
  group_by(model, prompt_frame, poll_name, subgroup_type, subgroup) %>%
  summarise(
    prop_on_mode = sum(llm_prop[response_option == first(direct_mode)]),
    .groups = "drop"
  )

# Summarise with CIs across polls x subgroups
demo_vs_direct_mode_summary <- demo_vs_direct_mode %>%
  group_by(model, prompt_frame, subgroup_type) %>%
  summarise(
    mean_prop_on_mode = mean(prop_on_mode),
    sd_prop_on_mode   = sd(prop_on_mode),
    n                 = n(),
    ci_lo = mean_prop_on_mode - qt(0.975, n - 1) * sd_prop_on_mode / sqrt(n),
    ci_hi = mean_prop_on_mode + qt(0.975, n - 1) * sd_prop_on_mode / sqrt(n),
    .groups = "drop"
  )

# Summarise by subgroup type only (pooling across models and prompt frames)
demo_vs_direct_mode_by_subgroup <- demo_vs_direct_mode %>%
  group_by(subgroup_type) %>%
  summarise(
    mean_prop_on_mode = mean(prop_on_mode),
    sd_prop_on_mode   = sd(prop_on_mode),
    n                 = n(),
    ci_lo = mean_prop_on_mode - qt(0.975, n - 1) * sd_prop_on_mode / sqrt(n),
    ci_hi = mean_prop_on_mode + qt(0.975, n - 1) * sd_prop_on_mode / sqrt(n),
    .groups = "drop"
  )

print(demo_vs_direct_mode_summary)
print(demo_vs_direct_mode_by_subgroup)

####################################
# RQ2: ACCURACY BY MODEL x FRAMING
####################################

aov_result <- aov(mae ~ model * prompt_frame, data = distance_full)
summary(aov_result)

####################################
# MAE TABLE: MODEL x FRAMING
####################################

# Embody & Specialist: MAE by model x prompt_frame (from distance_full)
mae_persona <- distance_full %>%
  group_by(model, prompt_frame) %>%
  summarise(
    mean_mae = mean(mae),
    sd_mae   = sd(mae),
    .groups  = "drop"
  )

# Direct: MAE comparing direct_props to GT averaged across demographics
# For each poll, average GT proportions across all subgroups to get an overall distribution
gt_overall <- gt_props %>%
  group_by(poll_name, response_option_combined) %>%
  summarise(gt_prop = mean(gt_prop), .groups = "drop")

direct_mae <- direct_props %>%
  right_join(gt_overall,
             by = c("poll_name", "response_option" = "response_option_combined")) %>%
  mutate(direct_prop = replace_na(direct_prop, 0)) %>%
  filter(!is.na(model)) %>%
  group_by(model, poll_name) %>%
  summarise(mae = mean(abs(direct_prop - gt_prop)), .groups = "drop") %>%
  group_by(model) %>%
  summarise(
    mean_mae = mean(mae),
    sd_mae   = sd(mae),
    .groups  = "drop"
  ) %>%
  mutate(prompt_frame = "direct")

# Combine into one table
mae_table <- bind_rows(mae_persona, direct_mae) %>%
  mutate(
    label = paste0(round(mean_mae * 100, 2), " ± ", round(sd_mae * 100, 2)),
    model = coalesce(model_display[model], model)
  ) %>%
  select(model, prompt_frame, label) %>%
  pivot_wider(names_from = model, values_from = label)

cat("\n=== MAE by Model x Framing (%) ===\n")
print(mae_table)
