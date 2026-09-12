# ============================================================
# QB ANALYSIS PROJECT: WHAT DRIVES WINNING?
# NFL Regular Season, 2021–2025
# Minimum 200 QB Dropbacks
# Author: Gavin Baskette
# ============================================================


# ---- R Libraries ----

library(nflfastR)
library(nflreadr)
library(dplyr)
library(cocor)
library(ggplot2)





# ---- 1. DATA LOADING AND INITIAL FILTERING ----

pbp <- load_pbp(2021:2025)

pbp <- pbp %>%
  filter(season_type == "REG")





# ---- 2. CREATING QB STATS ----

qb_stats <- pbp %>%
  filter(qb_dropback == 1) %>%
  group_by(passer_player_name, posteam, season) %>%
  summarise(
    dropbacks = n(),
    pass_attempts = sum(pass_attempt == 1 & sack == 0, na.rm = TRUE),
    completions = sum(complete_pass == 1, na.rm = TRUE),
    pass_yards = sum(passing_yards, na.rm = TRUE),
    pass_tds = sum(pass_touchdown == 1, na.rm = TRUE),
    interceptions = sum(interception == 1, na.rm = TRUE),
    epa_per_dropback = mean(epa, na.rm = TRUE),
    success_rate = mean(epa > 0, na.rm = TRUE),
    cpoe = mean(cpoe, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    yards_per_attempt = pass_yards / pass_attempts,
    td_pct = pass_tds / pass_attempts,
    int_pct = interceptions / pass_attempts,
    completion_pct = completions / pass_attempts,
    
    passer_rating = (
      pmax(pmin((completion_pct - 0.30) * 5, 2.375), 0) +
        pmax(pmin((yards_per_attempt - 3) * 0.25, 2.375), 0) +
        pmax(pmin(td_pct * 20, 2.375), 0) +
        pmax(pmin(2.375 - (int_pct * 25), 2.375), 0)
    ) / 6 * 100
  ) %>%
  filter(dropbacks >= 200)





# ---- 3. FINDING TEAM RECORDS ----

schedules <- load_schedules(2021:2025)


schedules <- schedules %>%
  filter(game_type == "REG")


home_results <- schedules %>%
  transmute(
    season,
    team = home_team,
    win = ifelse(home_score > away_score, 1, 0)
  )

away_results <- schedules %>%
  transmute(
    season,
    team = away_team,
    win = ifelse(away_score > home_score, 1, 0)
  )

team_records <- bind_rows(home_results, away_results) %>%
  group_by(season, team) %>%
  summarise(
    wins = sum(win),
    losses = n() - wins,
    win_pct = wins / n(),
    .groups = "drop"
  )





# ---- 4. JOINING QB AND TEAM DATA ----

qb_analysis <- qb_stats %>%
  left_join(
    team_records,
    by = c("posteam" = "team", "season" = "season")
  )





# ---- 5. EXPORTING PLAY-BY-PLAY DATA TO POSTGRESQL ----

qb_pbp <- pbp %>%
  select(
    season,
    passer_player_name,
    posteam,
    qb_dropback,
    pass_attempt,
    sack,
    complete_pass,
    passing_yards,
    pass_touchdown,
    interception,
    epa,
    cpoe
  )

write.csv(
  qb_pbp,
  "data/qb_pbp.csv",
  row.names = FALSE,
  na = ""
)





# ---- 6. VALIDATION: COMPARE SELECTED QB-SEASONS WITH SQL ----

# Confirm final dataset size
nrow(qb_analysis)

# Check for missing team records
sum(is.na(qb_analysis$win_pct))

# Compare selected QB-seasons with SQL output
qb_analysis %>% select(
  passer_player_name,
  posteam,
  season,
  dropbacks,
  epa_per_dropback,
  success_rate,
  cpoe,
  completion_pct,
  yards_per_attempt,
  td_pct,
  int_pct,
  passer_rating,
  win_pct
) %>% filter(passer_player_name %in% c("J.Burrow", "P.Mahomes")) %>%
  arrange(season, passer_player_name)





# ---- 7. CORRELATION ANALYSIS ----

cor_matrix <- cor(
  qb_analysis[, c(
    "epa_per_dropback",
    "success_rate",
    "cpoe",
    "completion_pct",
    "yards_per_attempt",
    "td_pct",
    "int_pct",
    "passer_rating",
    "win_pct"
  )],
  use = "complete.obs"
)

cor_matrix


correlations_with_wins <- cor_matrix[
  "win_pct",
  c(
    "epa_per_dropback",
    "success_rate",
    "cpoe",
    "completion_pct",
    "yards_per_attempt",
    "td_pct",
    "int_pct"
  )
]

sort(correlations_with_wins, decreasing = TRUE)





# ---- 8. TESTING IF DIFFERENCES ARE STATISTICALLY SIGNIFICANT ----

# EPA vs. Passer Rating
n <- nrow(na.omit(qb_analysis[, c(
  "epa_per_dropback",
  "passer_rating",
  "win_pct"
)]))

r.epa.win <- cor(
  qb_analysis$epa_per_dropback,
  qb_analysis$win_pct,
  use = "complete.obs"
)

r.pr.win <- cor(
  qb_analysis$passer_rating,
  qb_analysis$win_pct,
  use = "complete.obs"
)

r.epa.pr <- cor(
  qb_analysis$epa_per_dropback,
  qb_analysis$passer_rating,
  use = "complete.obs"
)

n
r.epa.win
r.pr.win
r.epa.pr

cocor.dep.groups.overlap(
  r.jk = r.epa.win,
  r.jh = r.pr.win,
  r.kh = r.epa.pr,
  n = n,
  test = "steiger1980"
)



# Success Rate vs. Y/A
r.sr.win <- cor(
  qb_analysis$success_rate,
  qb_analysis$win_pct,
  use = "complete.obs"
)

r.ya.win <- cor(
  qb_analysis$yards_per_attempt,
  qb_analysis$win_pct,
  use = "complete.obs"
)

r.sr.ya <- cor(
  qb_analysis$success_rate,
  qb_analysis$yards_per_attempt,
  use = "complete.obs"
)

cocor.dep.groups.overlap(
  r.jk = r.sr.win,
  r.jh = r.ya.win,
  r.kh = r.sr.ya,
  n = n,
  test = "steiger1980"
)



# Success Rate vs. TD%
r.td.win <- cor(
  qb_analysis$td_pct,
  qb_analysis$win_pct,
  use = "complete.obs"
)

r.sr.td <- cor(
  qb_analysis$success_rate,
  qb_analysis$td_pct,
  use = "complete.obs"
)

cocor.dep.groups.overlap(
  r.jk = r.sr.win,
  r.jh = r.td.win,
  r.kh = r.sr.td,
  n = n,
  test = "steiger1980"
)



# CPOE vs. Completion%
r.cmp.win <- cor(
  qb_analysis$completion_pct,
  qb_analysis$win_pct,
  use = "complete.obs"
)

r.cpoe.cmp <- cor(
  qb_analysis$cpoe,
  qb_analysis$completion_pct,
  use = "complete.obs"
)

cocor.dep.groups.overlap(
  r.jk = cor(
    qb_analysis$cpoe,
    qb_analysis$win_pct,
    use = "complete.obs"
  ),
  r.jh = r.cmp.win,
  r.kh = r.cpoe.cmp,
  n = n,
  test = "steiger1980"
)





# ---- 9. REGRESSION ANALYSIS ----

# EPA alone
model_epa <- lm(
  win_pct ~ epa_per_dropback,
  data = qb_analysis
)

summary(model_epa)


# Passer Rating alone
model_pr <- lm(
  win_pct ~ passer_rating,
  data = qb_analysis
)

summary(model_pr)


# EPA + Passer Rating
model_epa_pr <- lm(
  win_pct ~ epa_per_dropback + passer_rating,
  data = qb_analysis
)

summary(model_epa_pr)










# ---- 10. VISUALIZATIONS ----

# ---- VISUALIZATION 1: CORRELATION WITH WINNING ----

correlation_data <- data.frame(
  metric = c(
    "EPA / Dropback",
    "Passer Rating",
    "Success Rate",
    "Yards / Attempt",
    "TD %",
    "CPOE",
    "Completion %",
    "INT %"
  ),
  correlation = c(
    cor(qb_analysis$epa_per_dropback, qb_analysis$win_pct, use = "complete.obs"),
    cor(qb_analysis$passer_rating, qb_analysis$win_pct, use = "complete.obs"),
    cor(qb_analysis$success_rate, qb_analysis$win_pct, use = "complete.obs"),
    cor(qb_analysis$yards_per_attempt, qb_analysis$win_pct, use = "complete.obs"),
    cor(qb_analysis$td_pct, qb_analysis$win_pct, use = "complete.obs"),
    cor(qb_analysis$cpoe, qb_analysis$win_pct, use = "complete.obs"),
    cor(qb_analysis$completion_pct, qb_analysis$win_pct, use = "complete.obs"),
    cor(qb_analysis$int_pct, qb_analysis$win_pct, use = "complete.obs")
  )
)

correlation_data <- correlation_data %>%
  arrange(correlation) %>%
  mutate(
    metric = factor(metric, levels = metric)
  )

ggplot(correlation_data, aes(x = correlation, y = metric)) +
  geom_col() +
  geom_vline(xintercept = 0) +
  labs(
    title = "QB Metrics and Team Winning Percentage",
    subtitle = "Correlation across 183 QB-seasons, 2021–2025",
    x = "Correlation with Team Winning Percentage",
    y = NULL
  ) +
  theme_minimal()





# ---- VISUALIZATION 2: EPA VS. WINNING ----

ggplot(
  qb_analysis,
  aes(x = epa_per_dropback, y = win_pct)
) +
  geom_point() +
  geom_smooth(method = "lm", se = TRUE) +
  labs(
    title = "EPA per Dropback vs. Team Winning Percentage",
    subtitle = "NFL QB-seasons with at least 200 dropbacks, 2021–2025",
    x = "EPA per Dropback",
    y = "Team Winning Percentage"
  ) +
  theme_minimal()





# ---- VISUALIZATION 3: MODEL COMPARISON ----

model_comparison <- data.frame(
  model = c(
    "EPA / Dropback",
    "Passer Rating",
    "EPA + Passer Rating"
  ),
  r_squared = c(
    summary(model_epa)$r.squared,
    summary(model_pr)$r.squared,
    summary(model_epa_pr)$r.squared
  )
)

ggplot(
  model_comparison,
  aes(x = r_squared, y = factor(model, levels = rev(model)))
) +
  geom_col(width = 0.65) +
  geom_text(
    aes(label = sprintf("%.1f%%", r_squared * 100)),
    hjust = -0.15,
    size = 4
  ) +
  scale_x_continuous(
    limits = c(0, 0.55),
    labels = function(x) paste0(x * 100, "%")
  ) +
  labs(
    title = "EPA Explains More Winning Variation Than Passer Rating",
    subtitle = "R² from QB-season regression models, 2021–2025",
    x = "Variation in Team Winning Percentage Explained",
    y = NULL
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11),
    axis.text = element_text(size = 11),
    axis.title.x = element_text(size = 11),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank()
  )




