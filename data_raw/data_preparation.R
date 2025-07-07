library(dplyr)
library(readr)
library(rvest)
library(stringr)

ccc_raw <- read_csv("data_raw/CCC/ccc-phase3-public.csv")

claims <- paste(
  "against Trump",
  "against Donald Trump",
  "against President Trump",
  "against president Trump",
  "Against President Trump",
  "against the Trump administration",
  "against the Trump adminstration",
  "against the Trump Administration",
  "Against the Trump administration",
  "against President Donald Trump",
  "against the President Trump",
  "against the Trump",
  "against the anti-democratic and illegal actions of the Trump administration",
  "agaisnt Donald Trump",
  "against Donal Trump",
  "for the release of students abducted by the Trump adminstration",
  "against deportations",
  "against fascism",
  "for democracy",
  "against Elon Musk",
  "against the inauguration of President Donald Trump",
  "for warning the community about the consequences of Trumps agenda on immigrants and nonimmigrants",
  "against the unconstitutional power grab by President Donald Trump and Elon Musk",
  "against U.S. president Donald Trump",
  "for the removal and impeachment of President Trump",
  sep = "|"
)

# claims_pro <- paste(
#   "for Trump",
#   "for President Trump",
#   "for Donald Trump",
#   "in support of Trump",
#   "in support of President Trump",
#   "in support of president Trump",
#   "in support fo President Trump",
#   "in support of Donald Trump",
#   "in celebration of Donald Trump",
#   "in support of the Trump administration",
#   "for patriotism",
#   sep = "|"
# )

ccc_against_trump <- ccc_raw |> 
  filter(str_detect(claims_summary, claims)) 

ccc_states <- ccc_against_trump |> 
  group_by(state) |> 
  summarize(n_events = n(),
            n_part = sum(size_mean, na.rm = TRUE))

# American Presidency Project ---------------------------------------------

app <- read_html("data_raw/American_Presidency_Project/2024_The American Presidency Project.html")  |> 
  html_element("table") |> 
  html_table() |> 
  select(state = X1, pct_trump = X7) |> 
  slice(14:69) |> 
  filter(!(state %in% c("CD-1", "CD-2", "CD-3"))) |> 
  mutate(state = case_when(state == "District of Columbia" ~ "DC",
                           TRUE ~ state.abb[match(state, state.name)]),
         pct_trump = str_remove(pct_trump, "%"),
         pct_trump = as.numeric(pct_trump))


# KFF ---------------------------------------------------------------------

kff_pop <- read_csv("data_raw/KFF/kff_total_number_of_residents.csv",
                skip = 4,
                n_max = 52,
                col_names = c("state", "pop")) |> 
  mutate(state = case_when(state == "District of Columbia" ~ "DC",
                           state == "Puerto Rico" ~ "PR",
                           TRUE ~ state.abb[match(state, state.name)]),
         pop = pop / 1000000)

kff_income <- read_csv("data_raw/KFF/kff_median_annual_household_income.csv",
                       skip = 4,
                       n_max = 52,
                       col_names = c("state", "income")) |> 
  mutate(state = case_when(state == "District of Columbia" ~ "DC",
                           state == "Puerto Rico" ~ "PR",
                           TRUE ~ state.abb[match(state, state.name)]),
         income = str_remove(income, "\\$") |> as.numeric(),
         income = income / 1000)


kff_ethnicity <- read_csv("data_raw/KFF/kff_population_distribution_by_race_ethnicity.csv",
                          skip = 4,
                          n_max = 52,
                          col_names = FALSE
                       ) |> 
  select(state = X1, 
         black = X3, 
         hispanic = X4) |> 
  mutate(state = case_when(state == "District of Columbia" ~ "DC",
                           state == "Puerto Rico" ~ "PR",
                           TRUE ~ state.abb[match(state, state.name)]),
         black = black * 100,
         hispanic = hispanic * 100)


kff_citizenship <- read_csv("data_raw/KFF/kff_population_distribution_by_citizenship_status.csv",
                            skip = 4,
                            n_max = 52,
                            col_names = FALSE) |> 
  mutate(
    state = case_when(X1 == "District of Columbia" ~ "DC",
                      X1 == "Puerto Rico" ~ "PR",
                      TRUE ~ state.abb[match(X1, state.name)]),
    across(c(X4, X5, X5), as.numeric),
    pct_non_citizens = ((X4 + X5) / X6) * 100
  ) |> 
  select(state, pct_non_citizens)


kff_gov_party <- read_csv("data_raw/KFF/kff_state_political_parties.csv",
                          skip = 4,
                          n_max = 52,
                          col_names = FALSE) |> 
  select(state = X1,
         gov_party = X2) |> 
  mutate(
    state = case_when(state == "District of Columbia" ~ "DC",
                      state == "Puerto Rico" ~ "PR",
                      TRUE ~ state.abb[match(state, state.name)]),
    gov_party = factor(gov_party)
  )


# Join --------------------------------------------------------------------

ccc_states_merged <- ccc_states |> 
  left_join(kff_pop, by = "state") |> 
  mutate(n_events_pop = n_events/pop,
         n_events_pop_log = log(n_events_pop),
         n_part_pop = n_part/(pop * 1000),
         n_part_pop = round(n_part_pop) # for the count models
         ) |> 
  left_join(app, by = "state") |> 
  left_join(kff_income, by = "state") |> 
  left_join(kff_ethnicity, by = "state") |> 
  left_join(kff_citizenship, by = "state") |> 
  left_join(kff_gov_party, by = "state")


# Save --------------------------------------------------------------------

saveRDS(ccc_states_merged, file = "data/ccc_states_merged.rds")


# Export subsample --------------------------------------------------------

set.seed(123)

ccc_sub <- ccc_against_trump |>
  filter(!is.na(claims_verbatim) & !is.na(title)) |> 
  mutate(percentile = percent_rank(size_mean)) |>       # 1. Compute percentiles (0 to 1)
  filter(percentile >= 0.9) |>                         # 2. Keep top 10%
  slice_sample(n = 50)                                  # 3. Random sample of 50 rows

write_csv(ccc_sub, file = "ccc_sub.csv")
