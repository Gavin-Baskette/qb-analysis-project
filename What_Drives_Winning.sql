-- ============================================================
-- QB ANALYSIS PROJECT: WHAT DRIVES WINNING?
-- PostgreSQL Analysis
-- 2021–2025 NFL Regular Season
-- Minimum 200 QB Dropbacks
-- ============================================================

DROP TABLE IF EXISTS public.qb_analysis;

CREATE TABLE public.qb_analysis AS

WITH team_records AS (
    SELECT
        season,
        team,
        SUM(win) AS wins,
        COUNT(*) - SUM(win) AS losses,
        AVG(win::numeric) AS win_pct
    FROM (
        -- Home games
        SELECT
            season,
            home_team AS team,
            CASE
                WHEN home_score > away_score THEN 1
                ELSE 0
            END AS win
        FROM public.schedules

        UNION ALL

        -- Away games
        SELECT
            season,
            away_team AS team,
            CASE
                WHEN away_score > home_score THEN 1
                ELSE 0
            END AS win
        FROM public.schedules
    ) AS all_results
    GROUP BY season, team
),

qb_stats AS (
    SELECT
        passer_player_name,
        posteam,
        season,

        -- Total QB dropbacks
        COUNT(*) AS dropbacks,

        -- Traditional passing statistics
        SUM(
            CASE
                WHEN pass_attempt = 1
                 AND sack = 0
                THEN 1
                ELSE 0
            END
        ) AS pass_attempts,

        SUM(
            CASE
                WHEN complete_pass = 1
                THEN 1
                ELSE 0
            END
        ) AS completions,

        SUM(passing_yards) AS pass_yards,

        SUM(
            CASE
                WHEN pass_touchdown = 1
                THEN 1
                ELSE 0
            END
        ) AS pass_tds,

        SUM(
            CASE
                WHEN interception = 1
                THEN 1
                ELSE 0
            END
        ) AS interceptions,

        -- Advanced statistics
        AVG(epa) AS epa_per_dropback,

        AVG(
            CASE
                WHEN epa > 0 THEN 1.0
                ELSE 0.0
            END
        ) AS success_rate,

        AVG(cpoe) AS cpoe

    FROM public.qb_pbp
    WHERE qb_dropback = 1
    GROUP BY
        passer_player_name,
        posteam,
        season
),

qb_metrics AS (
    SELECT
        q.*,

        -- Yards per attempt
        q.pass_yards::numeric
            / NULLIF(q.pass_attempts, 0)
            AS yards_per_attempt,

        -- Touchdown percentage
        q.pass_tds::numeric
            / NULLIF(q.pass_attempts, 0)
            AS td_pct,

        -- Interception percentage
        q.interceptions::numeric
            / NULLIF(q.pass_attempts, 0)
            AS int_pct,

        -- Completion percentage
        q.completions::numeric
            / NULLIF(q.pass_attempts, 0)
            AS completion_pct

    FROM qb_stats AS q
),

qb_final AS (
    SELECT
        q.*,

        -- Official NFL passer rating formula
        (
            GREATEST(
                LEAST(
                    (q.completion_pct - 0.30) * 5,
                    2.375
                ),
                0
            )
            +
            GREATEST(
                LEAST(
                    (q.yards_per_attempt - 3) * 0.25,
                    2.375
                ),
                0
            )
            +
            GREATEST(
                LEAST(
                    q.td_pct * 20,
                    2.375
                ),
                0
            )
            +
            GREATEST(
                LEAST(
                    2.375 - (q.int_pct * 25),
                    2.375
                ),
                0
            )
        ) / 6 * 100 AS passer_rating

    FROM qb_metrics AS q
)

-- ============================================================
-- 5. CREATE FINAL ANALYSIS TABLE
-- ============================================================

SELECT
    q.*,
    t.wins,
    t.losses,
    t.win_pct

FROM qb_final AS q

LEFT JOIN team_records AS t
    ON q.posteam = t.team
    AND q.season = t.season

WHERE q.dropbacks >= 200

ORDER BY
    q.season,
    q.passer_player_name;





-- ============================================================
-- VALIDATION: COMPARE SELECTED QB-SEASONS WITH R
-- ============================================================
SELECT COUNT(*) AS qb_seasons
FROM public.qb_analysis;

SELECT COUNT(*) AS missing_win_pct
FROM public.qb_analysis
WHERE win_pct IS NULL;

SELECT
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
FROM public.qb_analysis
WHERE passer_player_name IN ('J.Burrow', 'P.Mahomes')
ORDER BY season, passer_player_name;



