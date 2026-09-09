-- =============================================================================
-- 06_search.sql — BSH Documents Table + Cortex Search Service
--
-- Creates a document corpus of ~30 BSH press release excerpts, product
-- descriptions, and market context documents. These give the Cortex Agent
-- the ability to answer qualitative questions like:
--   "Why did the Cooking category decline in 2024?"
--   "What is Home Connect?"
--   "What makes Gaggenau different from Bosch?"
--
-- The Cortex Search Service is built on the DOCUMENT_TEXT column and
-- referenced by the agent in 08_agent.sql.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE IDENTIFIER('<% wh_name %>');
USE DATABASE  IDENTIFIER('<% db_name %>');
USE SCHEMA FIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- Document table
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE BSH_DOCUMENTS (
    DOC_ID           NUMBER         NOT NULL AUTOINCREMENT PRIMARY KEY,
    TITLE            VARCHAR(200)   COMMENT 'Document title',
    DOCUMENT_TYPE    VARCHAR(50)    COMMENT 'Type: PRESS_RELEASE | PRODUCT_BRIEF | MARKET_ANALYSIS | BRAND_GUIDE',
    YEAR             NUMBER(4)      COMMENT 'Publication or reference year',
    SOURCE           VARCHAR(100)   COMMENT 'Source organisation or publication',
    DOCUMENT_TEXT    VARCHAR(16777216) COMMENT 'Full document text — indexed by Cortex Search'
)
COMMENT = 'BSH Group document corpus: press releases, product briefs, and market context. '
          'Indexed by BSH_PNL_SEARCH_SVC for the Cortex Agent qualitative QA tool.';

INSERT INTO BSH_DOCUMENTS (TITLE, DOCUMENT_TYPE, YEAR, SOURCE, DOCUMENT_TEXT) VALUES

('BSH Group 2024 Annual Results — Press Release',
 'PRESS_RELEASE', 2024, 'BSH Hausgeräte GmbH Press Release April 2025',
 'BSH Hausgeräte GmbH achieved a turnover of 15.3 billion euros in fiscal year 2024, '
 'recording year-over-year growth of 3%, or 7.5% after adjustment for exchange rate effects. '
 'Europe remains BSH's largest region at 6.9 billion euros. North America posted approximately '
 '700 million euros, benefiting from high demand for premium appliances. '
 'BSH invested 835 million euros in research and development in 2024, representing 5.5% of revenue '
 'and well above the industry average. EBIT margin reached approximately 6%. '
 'CEO Dr Matthias Metz: "Despite challenging market conditions — particularly the continued '
 'weakness in demand for built-in appliances linked to the European real estate cycle — '
 'BSH delivered solid results driven by our premium brand portfolio and digital innovation."'),

('BSH Group 2023 Annual Results — Press Release',
 'PRESS_RELEASE', 2023, 'BSH Hausgeräte GmbH Press Release April 2024',
 'BSH Hausgeräte GmbH posted annual revenue of 14.9 billion euros in 2023. '
 'Europe contributed 6.7 billion euros. The Asia-Pacific and Emerging Markets regions '
 'showed resilient growth, driven particularly by e-commerce channel penetration in China. '
 'BSH has been carbon neutral in its manufacturing operations since 2020. '
 'Research and development expenditure was 820 million euros (5.5% of revenue). '
 'BSH completed its network of 10 Experience and Design Centers across North America in 2024, '
 'starting with openings in Miami, Vancouver, and Houston during the year, '
 'followed by Beverly Hills and Washington D.C. in early 2025.'),

('Category Performance 2024: Cooking Decline Explained',
 'MARKET_ANALYSIS', 2024, 'BSH Internal Market Intelligence',
 'The Cooking category declined 4.6% in 2024, primarily driven by the continued slump '
 'in demand for built-in kitchen appliances. The European residential property market '
 'experienced a multi-year correction as mortgage rates rose sharply from 2022 to 2024. '
 'New kitchen installations — the primary driver of built-in oven and hob purchases — '
 'fell significantly as housing transactions declined. '
 'The Cooking decline is concentrated in built-in ovens and hobs sold through the '
 'Built-in/Project channel (distribution channel 20). '
 'Freestanding cooking appliances and small kitchen appliances held up better. '
 'BSH expects a gradual recovery as European real estate markets stabilise. '
 'The Bretten and Traunreut plants have been partially retooled for the new premium '
 'oven series, representing an investment of approximately 100 million euros.'),

('Category Performance 2024: Laundry Care and Consumer Products Growth',
 'MARKET_ANALYSIS', 2024, 'BSH Internal Market Intelligence',
 'Laundry Care was BSH's strongest large-appliance category in 2024, growing 4.1%. '
 'Growth was driven by the shift to premium energy-efficient models (A-rated) as '
 'European consumers replaced older appliances under the EU energy label framework. '
 'The Bosch Serie 8 EcoSilence range and Siemens iQ700 line saw strong demand. '
 'Consumer Products (small appliances) grew 5.5%, led by fully automatic coffee machines. '
 'The Bosch VeroBar AromaPro and Siemens EQ900 are the flagship coffee machines. '
 'The Asia-Pacific region was the fastest-growing market for small appliances, '
 'with particularly strong demand for coffee machines and floor care products. '
 'Dish Care grew 3.2%, supported by the launch of Bosch PerfectDry Extra Clean Zone '
 'dishwashers and Siemens zeolite technology models. '
 'Cooling declined slightly (-0.4%) in line with the broader kitchen appliance weakness.'),

('Gaggenau Brand Positioning — The Art of Exceptional Cooking',
 'BRAND_GUIDE', 2024, 'BSH Brand Communications',
 'Gaggenau is one of the world''s most exclusive home appliance brands, founded in 1683. '
 'The brand targets professional chefs and culinary enthusiasts who demand '
 'uncompromising performance and precision engineering. '
 'Gaggenau products are designed and manufactured in Germany, with a philosophy of '
 '"form follows function" — every design decision is driven by culinary performance. '
 'Key product lines: the BO480 Combi-Steam Oven (list price EUR 3,800) combines '
 'dry heat, steam, and sous-vide in one appliance. The CX482 Full Surface Induction '
 'cooktop (EUR 4,500) turns the entire surface into one responsive cooking zone. '
 'Gaggenau commands significantly higher gross margins than BSH''s volume brands. '
 'Trade discounts to channel partners are minimal — Gaggenau typically sells through '
 'exclusive kitchen design studios and luxury appliance retailers. '
 'The brand is heavily concentrated in DACH and Western Europe, with select presence '
 'in North America and APAC through high-end kitchen designers.'),

('NEFF Slide-Hide — The Brand for Cooking Enthusiasts',
 'BRAND_GUIDE', 2024, 'BSH Brand Communications',
 'NEFF was founded in 1877 and has been part of BSH since 1984. '
 'The brand is positioned for passionate home cooks — people who genuinely love cooking '
 'and want appliances that enhance the cooking experience. '
 'The signature product is the Slide-Hide oven, where the door slides under the cavity '
 'rather than swinging down. This allows cooks to stand close to the oven while cooking, '
 'reach inside easily, and use the top of the oven as extra worktop space. '
 'The Slide-Hide B57VR22N0B (EUR 999) features pyrolytic self-cleaning and CircoTherm '
 'fan technology for even heat distribution. '
 'NEFF is sold exclusively as built-in appliances — the brand does not offer freestanding models. '
 'Primary markets are Germany, UK, Ireland, and Australia. '
 'The brand commands a modest price and margin premium over Bosch''s standard built-in range.'),

('Bosch Brand Overview — Invented for Life',
 'BRAND_GUIDE', 2024, 'BSH Brand Communications',
 'Bosch is BSH''s largest brand by volume and revenue (approximately 50% of group turnover). '
 'The brand promise is "Invented for Life" — technology that improves everyday life. '
 'Bosch is the trusted, reliable choice for the majority of European households. '
 'Product ranges are organised in numbered series: Serie 2 (entry), Serie 4 (mid), '
 'Serie 6 (upper-mid), Serie 8 (premium). '
 'Flagship products: Bosch Serie 8 PerfectDry dishwasher (SMV6ZCX00E, EUR 799) '
 'featuring zeolite drying technology and Extra Clean Zone. '
 'Bosch Serie 8 EcoSilence washing machine (WGB254A0GB, EUR 1,199) with Home Connect. '
 'Bosch VeroBar AromaPro coffee machine (CTL636ES6, EUR 1,199) — fully automatic. '
 'Bosch is distributed through all channels: specialist retail, mass retail, '
 'e-commerce (Amazon), built-in/project, and B2B. '
 'Gross margins are lower than Gaggenau/Thermador but volume compensates.'),

('Siemens Brand Overview — Future Made in Germany',
 'BRAND_GUIDE', 2024, 'BSH Brand Communications',
 'Siemens is BSH''s second-largest brand (approximately 28% of group turnover). '
 'BSH is the trademark licensee for the Siemens brand in home appliances. '
 'The brand is positioned slightly above Bosch — premium engineering with a more '
 'sophisticated aesthetic. Primary markets are Europe and China. '
 'The iQ series ranges from iQ300 (entry), iQ500 (mid), iQ700 (premium) to studioLine (luxury). '
 'Flagship: Siemens EQ900 TQ907D03 coffee machine (EUR 1,299) — voice-controlled, '
 'AI-powered personalisation. Siemens KF96NAXEA iQ700 FrenchDoor refrigerator (EUR 1,699). '
 'Siemens studioLine ovens (HS858GXS6B, EUR 1,499) — flush-fitting, premium built-in. '
 'Siemens has a strong presence in the built-in channel alongside NEFF and Gaggenau.'),

('Thermador — Ultra-Luxury Appliances for North America',
 'BRAND_GUIDE', 2024, 'BSH Brand Communications',
 'Thermador is BSH''s ultra-premium North American brand. '
 'Thermador is synonymous with professional-grade kitchen appliances for discerning '
 'American and Canadian consumers. The brand was founded in Los Angeles in 1916. '
 'Key products: Thermador MEDS607BS 30-inch Double Wall Oven (USD ~4,500), '
 'T36IT905NP Column Refrigerator (USD ~6,200), DWHD771WFP StarDry dishwasher (USD ~2,200). '
 'Thermador is sold exclusively through premium kitchen dealers, design showrooms, '
 'and BSH''s Experience and Design Centers. No mass retail distribution. '
 'Thermador commands the highest gross margins in the BSH portfolio. '
 'Trade discounts are minimal. The brand is a key contributor to BSH''s North America '
 'profitability despite relatively low revenue volume.'),

('Home Connect — BSH Smart Home Ecosystem',
 'PRODUCT_BRIEF', 2024, 'BSH Digital Services',
 'Home Connect is BSH''s cross-brand smart home platform, launched in 2014. '
 'It allows consumers to control and monitor Bosch and Siemens appliances '
 'via smartphone app, voice assistants (Amazon Alexa, Google Home), and Matter protocol. '
 'At IFA 2024 in Berlin, BSH presented the world''s first Matter-enabled home appliance, '
 'a Bosch fridge-freezer combination from the Giengen factory. '
 'Matter is an open standard that allows appliances from different manufacturers '
 'to communicate — a milestone for smart home interoperability. '
 'Home Connect has over 20 million connected appliances globally. '
 'Features include: remote start/stop, program selection, push notifications, '
 'predictive maintenance alerts, and energy consumption monitoring. '
 'Smart appliances carry a price premium of EUR 50-200 over non-connected equivalents.'),

('IFA 2024 Berlin — BSH Innovation Highlights',
 'PRESS_RELEASE', 2024, 'BSH Hausgeräte GmbH',
 'BSH presented major innovations at IFA 2024 in Berlin (September). '
 'The centrepiece was the world''s first Matter-enabled home appliance — a Bosch '
 'fridge-freezer combination (XXL, energy-saving) from the Giengen plant. '
 'The new Bosch product line of fridge-freezer combinations uses carbon-reduced materials '
 'and bio-based raw materials, reducing the carbon footprint by more than 50%. '
 'BSH also unveiled retrofittable microplastics filters for washing machines, '
 'capturing up to 97% of released particles. A downloadable microplastics '
 'reduction program for existing compatible machines reduces fibre abrasion by up to 30%. '
 'September is a seasonally strong month for BSH as IFA launches drive consumer demand '
 'for new models and create trading activity in the run-up to the Christmas season.'),

('BSH Sustainability: Carbon-Neutral Operations Since 2020',
 'PRESS_RELEASE', 2023, 'BSH Hausgeräte GmbH',
 'BSH has achieved carbon-neutral operations across all its manufacturing sites '
 'worldwide since 2020. The target is to reach 100% green electricity usage by 2030. '
 'BSH is committed to reducing Scope 3 emissions by 20% by 2030 compared to a 2019 baseline. '
 'Key sustainability innovations: zeolite dishwasher technology (natural silicate mineral '
 'that extracts moisture and releases it as heat, cutting drying energy by up to 50%), '
 'A-rated heat pump dryers (60-70% more energy efficient than condenser models), '
 'and the Home Connect energy monitoring dashboard. '
 'Sustainability is increasingly a purchasing driver, particularly in Germany and '
 'Northern Europe, supporting premium pricing for energy-efficient models.'),

('Bosch PerfectDry Dishwasher Technology',
 'PRODUCT_BRIEF', 2024, 'BSH Product Marketing',
 'The Bosch PerfectDry dishwasher range (Serie 6 and Serie 8) uses zeolite technology '
 'for highly efficient drying. Zeolite is a naturally occurring silicate mineral that '
 'absorbs moisture and releases it as heat, eliminating the need for a heating element '
 'in the drying phase. '
 'The BSH Serie 8 SMS8YCX02G adds the Extra Clean Zone — a dedicated spray arm that '
 'focuses intensive cleaning on heavily soiled items in the lower basket. '
 'The third basket (cutlery tray) increases capacity by 25%. '
 'PerfectDry models carry the EU A energy rating. '
 'Retail price: Bosch SMV6ZCX00E fully-integrated (EUR 799), SMS8YCX02G freestanding (EUR 999). '
 'These models are top sellers in Germany, UK, and the Netherlands.'),

('Bosch Washing Machine: EcoSilence Drive Technology',
 'PRODUCT_BRIEF', 2024, 'BSH Product Marketing',
 'EcoSilence Drive is BSH''s brushless motor technology used in Bosch and Siemens '
 'washing machines. The motor has no carbon brushes — it is maintenance-free, '
 'energy-efficient, and extremely quiet (under 72 dB in spin). '
 'The Bosch Serie 8 WGB254A0GB (10kg, EUR 1,199) achieves EU A energy rating, '
 'washing 4 shirts in 15 minutes on the SpeedPerfect programme. '
 'Home Connect integration allows remote start and energy monitoring. '
 'The Michalovce plant in Slovakia is the primary European production site for '
 'washing machines and tumble dryers.'),

('Siemens EQ900 Coffee Machine — AI-Powered Personalisation',
 'PRODUCT_BRIEF', 2024, 'BSH Product Marketing',
 'The Siemens EQ900 TQ907D03 (EUR 1,299) is BSH''s most advanced fully automatic '
 'coffee machine. It uses iAroma System bean recognition to adjust the grinder '
 'settings automatically for different coffee varieties. '
 'The machine learns individual user preferences and recommends personalised recipes. '
 'It connects to Home Connect for remote operation and maintenance alerts. '
 'The EQ900 has an intuitive TFT touchscreen with swipe navigation. '
 'The barista function creates latte macchiato and cappuccino automatically. '
 'Coffee machines are BSH''s fastest-growing product category in the Consumer Products segment, '
 'particularly in Germany, Italy, and the Asia-Pacific region.'),

('North America Strategy: Experience and Design Centers',
 'MARKET_ANALYSIS', 2024, 'BSH Regional Market Intelligence',
 'BSH North America posted approximately 700 million euros in 2024 revenue, '
 'growing just under 3% year-over-year and gaining market share. '
 'North America is designated as a growth market for BSH. '
 'The key strategic initiative is the expansion of the Experience and Design Center (EDC) network. '
 'By 2025 there are 10 EDCs across the US and Canada, with recent openings in '
 'Miami, Vancouver, Houston (2024) and Beverly Hills, Washington D.C. (2025). '
 'EDCs serve premium consumers, architects, and kitchen designers — the primary '
 'influencers for Thermador and Gaggenau purchases. '
 'BSH North America markets three brands: Bosch (broad distribution), '
 'Thermador (exclusive luxury dealers), and Gaggenau (ultra-luxury design studios). '
 'Manufacturing: New Bern, NC produces dishwashers, ranges, and wall ovens for the US market.'),

('APAC Strategy: E-Commerce Channel Penetration in China',
 'MARKET_ANALYSIS', 2024, 'BSH Regional Market Intelligence',
 'China is BSH''s largest Asia-Pacific market, operating primarily through '
 'e-commerce channels: JD.com (Jingdong) and Tmall (Alibaba). '
 'These two platforms account for over 50% of Chinese online appliance sales. '
 'Siemens is the stronger brand in China versus Bosch, reflecting historical '
 'association with German engineering quality among Chinese consumers. '
 'Small appliances (coffee machines, food processors) are the fastest-growing '
 'category in APAC, particularly in the 25-45 age demographic in tier-1 and tier-2 cities. '
 'BSH''s Chuzhou plant (Anhui province) produces washing machines and small appliances '
 'for the APAC market. '
 'The Chinese dishwasher market is growing rapidly as urban apartment sizes increase '
 'and dual-income households seek time-saving appliances.'),

('Distribution Channel Economics — Built-in vs Retail vs E-Commerce',
 'MARKET_ANALYSIS', 2024, 'BSH Internal Finance',
 'The Built-in/Project channel (channel 20) typically commands the highest list prices '
 'and lowest trade discounts, as kitchen studios and designers add their own margin. '
 'Brands Gaggenau, NEFF, and Siemens studioLine are concentrated in this channel. '
 'The Retail Specialist channel (channel 10) — MediaMarkt, Currys, Fnac Darty — '
 'is the highest-volume channel. Trade discounts are significant (8-12% of gross). '
 'E-Commerce (channel 30) has grown rapidly since 2020. Amazon is the largest '
 'single e-commerce customer in most European markets. '
 'E-commerce margins are generally lower due to returns rates and listing fees. '
 'B2B/Commercial (channel 40) covers hotels, commercial kitchens, and service contracts. '
 'This channel has grown with the recovery of the hospitality industry post-2021.'),

('BSH Marginal Contribution (Deckungsbeitrag) Structure',
 'MARKET_ANALYSIS', 2024, 'BSH Internal Finance Methodology',
 'BSH uses a multi-level marginal contribution (Deckungsbeitrag, DB) structure '
 'for internal profit reporting, consistent with German management accounting practice. '
 'DB1 (Marginal Contribution 1): Gross Revenue minus trade deductions, returns, '
 'cost of goods sold, and logistics. This measures the product-level contribution. '
 'DB2 (Marginal Contribution 2): DB1 minus brand advertising & promotion and sales costs. '
 'This measures the brand-level contribution after commercial investment. '
 'EBIT: DB2 minus research & development and general & administrative expenses. '
 'Gaggenau has the highest DB1 and DB2 margins in the portfolio, reflecting '
 'its premium price points, minimal trade discounts, and controlled distribution. '
 'Bosch and Siemens have lower margins but contribute the most in absolute euros '
 'due to volume.'),

('BSH Manufacturing Excellence — Plants and Capabilities',
 'PRESS_RELEASE', 2023, 'BSH Hausgeräte GmbH',
 'BSH operates 39 factories across Europe, North America, Africa, and Asia. '
 'Key European plants: '
 'Giengen (Baden-Württemberg): dishwashers — global technology centre with '
 'flexible assembly lines producing over 1,500 variants. '
 'Dillingen (Bavaria): refrigerators and freezers. '
 'Traunreut (Bavaria): cooking appliances. '
 'Bretten (Baden): ovens — 100 million EUR investment in 2024 for the new oven series. '
 'Outside Germany: Michalovce (Slovakia) produces washing machines and dryers for Europe. '
 'Chuzhou (China) serves the APAC market. '
 'New Bern (North Carolina, USA) manufactures dishwashers, ranges, and wall ovens '
 'for North America. '
 'Çerkezköy (Turkey) focuses on small appliances and coffee machines for Emerging Markets.');

-- ─────────────────────────────────────────────────────────────────────────────
-- Grant access to demo roles (inherited by parent roles via hierarchy)
-- ─────────────────────────────────────────────────────────────────────────────
GRANT SELECT ON TABLE BSH_DOCUMENTS TO ROLE BSH_EUROPE_DEMO_ROLE;
GRANT SELECT ON TABLE BSH_DOCUMENTS TO ROLE BSH_NA_DEMO_ROLE;
GRANT SELECT ON TABLE BSH_DOCUMENTS TO ROLE BSH_APAC_DEMO_ROLE;
-- Grant INSERT/TRUNCATE to the CI/CD service role for document refresh runs
GRANT INSERT, TRUNCATE ON TABLE BSH_DOCUMENTS TO ROLE BSH_DATA_DEPLOY_ROLE;

-- ─────────────────────────────────────────────────────────────────────────────
-- Cortex Search Service
-- Indexes the DOCUMENT_TEXT column for semantic similarity search.
-- The agent uses this to answer qualitative/contextual questions.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE CORTEX SEARCH SERVICE BSH_PNL_SEARCH_SVC
    ON document_text
    ATTRIBUTES title, document_type, year, source
    WAREHOUSE = IDENTIFIER('<% wh_name %>')
    TARGET_LAG = '1 day'
    COMMENT = 'BSH document corpus search service — press releases, product briefs, market context. '
              'Used by BSH_PNL_AGENT for qualitative QA alongside structured PnL data.'
    AS (
        SELECT document_text, title, document_type, year, source
        FROM IDENTIFIER('<% db_name %>').FIN.BSH_DOCUMENTS
    );

SELECT 'Documents indexed: ' || COUNT(*) AS status FROM BSH_DOCUMENTS;
