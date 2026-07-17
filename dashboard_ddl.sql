-- ============================================================
-- 抖音达人种草营销数据看板 — 完整数据库 DDL
-- 版本: v1.0 | 2026-07-16
-- 包含: 维度表 8 张 / 事实表 4 张 / 缝合表 1 张 / 汇总表 1 张 / 管理表 5 张
-- ============================================================

-- ============================================================
-- PART 1: ID映射层 (Mapping Layer)
-- ============================================================

-- 1.1 达人ID映射表
CREATE TABLE dim_creator_mapping (
    mapping_id              BIGSERIAL PRIMARY KEY,
    -- 各平台达人标识
    xingtu_creator_uid      VARCHAR(64),       -- 星图达人UID（最稳定）
    douyin_open_id          VARCHAR(64),       -- 抖音开放平台open_id
    douyin_sec_uid          VARCHAR(128),      -- 抖音sec_uid
    qianchuan_creator_id    VARCHAR(64),       -- 千川达人ID
    luopan_creator_id       VARCHAR(64),       -- 罗盘达人ID
    -- 达人基础信息（以星图为准）
    nickname                VARCHAR(128),
    fan_count               BIGINT,
    category                VARCHAR(64),        -- 达人分类
    tier                    VARCHAR(8),         -- 头/肩/腰/尾
    -- 目的标签
    exposure_rating         VARCHAR(2),         -- 曝光型评级 A/B/C
    seeding_rating          VARCHAR(2),         -- 种草型评级 A/B/C
    conversion_rating       VARCHAR(2),         -- 转化型评级 A/B/C
    -- 运维
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW(),
    CONSTRAINT chk_at_least_one_id CHECK (
        xingtu_creator_uid IS NOT NULL OR douyin_open_id IS NOT NULL
    )
);
CREATE UNIQUE INDEX idx_cm_xingtu_uid ON dim_creator_mapping(xingtu_creator_uid) WHERE xingtu_creator_uid IS NOT NULL;
CREATE UNIQUE INDEX idx_cm_open_id    ON dim_creator_mapping(douyin_open_id)     WHERE douyin_open_id IS NOT NULL;


-- 1.2 内容/素材ID映射表 (核心缝合枢纽)
CREATE TABLE dim_content_mapping (
    mapping_id              BIGSERIAL PRIMARY KEY,
    -- 各平台内容标识
    xingtu_video_id         VARCHAR(64),       -- 星图视频ID (主锚点)
    douyin_video_id         VARCHAR(64),       -- 抖音原生视频ID
    qianchuan_mat_id        VARCHAR(64),       -- 千川素材ID (可能多条投放)
    qianchuan_ad_id         VARCHAR(64),       -- 千川广告计划ID
    ocean_engine_ad_id      VARCHAR(64),       -- 巨量引擎广告计划ID
    ocean_engine_adgroup_id VARCHAR(64),       -- 巨量引擎广告组ID
    ocean_engine_creative_id VARCHAR(64),      -- 巨量引擎创意ID
    -- 原生加热标识
    douplus_order_id        VARCHAR(64),       -- DOU+订单ID
    xingzhitou_order_id     VARCHAR(64),       -- 星智投订单ID
    shengliangbao_plan_id   VARCHAR(64),       -- 声量宝计划ID
    -- 产品归类
    ad_product_type         VARCHAR(32),       -- brand_zone/feeds_live/seeding_cpt/seeding_bidding/ad_feed/topview/native_douplus/native_xingzhitou/native_shengliangbao
    is_seeding_pass         BOOLEAN DEFAULT FALSE,
    seeding_pass_type       VARCHAR(16),       -- cpt/bidding
    is_unified              BOOLEAN DEFAULT FALSE, -- 是否全域推广/乘方
    -- 关联达人
    creator_mapping_id      BIGINT REFERENCES dim_creator_mapping(mapping_id),
    -- 内容属性
    video_title             VARCHAR(512),
    publish_date            DATE,
    duration_seconds        INT,
    campaign_purpose        VARCHAR(16),       -- exposure/seeding/conversion
    content_type            VARCHAR(32),       -- 测评/教程/Vlog/口播/剧情
    -- 运维
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);
CREATE UNIQUE INDEX idx_cm_xingtu_vid     ON dim_content_mapping(xingtu_video_id)     WHERE xingtu_video_id IS NOT NULL;
CREATE UNIQUE INDEX idx_cm_qianchuan_mat  ON dim_content_mapping(qianchuan_mat_id)    WHERE qianchuan_mat_id IS NOT NULL;
CREATE INDEX idx_cm_ocean_ad             ON dim_content_mapping(ocean_engine_ad_id)  WHERE ocean_engine_ad_id IS NOT NULL;
CREATE INDEX idx_cm_douplus              ON dim_content_mapping(douplus_order_id)    WHERE douplus_order_id IS NOT NULL;


-- 1.3 商品ID映射表
CREATE TABLE dim_product_mapping (
    mapping_id              BIGSERIAL PRIMARY KEY,
    brand_sku_code          VARCHAR(64),       -- 品牌自有SKU编码 (锚点)
    xingtu_product_id       VARCHAR(64),       -- 星图挂车商品ID
    qianchuan_product_id    VARCHAR(64),       -- 千川商品ID
    luopan_spu_id           VARCHAR(64),       -- 罗盘SPU ID
    luopan_sku_id           VARCHAR(64),       -- 罗盘SKU ID
    product_name            VARCHAR(256),
    category                VARCHAR(64),
    base_price              DECIMAL(10,2),
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- PART 2: 广告产品维度层 (Ad Product Dimension)
-- ============================================================

-- 2.1 广告产品类型维度表
CREATE TABLE dim_ad_product (
    product_id              VARCHAR(32) PRIMARY KEY,
    product_name            VARCHAR(64),       -- 品牌专区/FeedsLive/种草通合约/种草通竞价/竞价信息流/TopView/DOU+/声量宝/星智投/短视频引流/直播引流/商品卡/全域推广/乘方
    product_category        VARCHAR(16),       -- brand/bidding/seeding/native/qianchuan
    platform                VARCHAR(16),       -- ocean_engine/xingtu/qianchuan/douyin_native
    optimize_goal           VARCHAR(32),       -- impression/click/engagement/follow/search_guide/product_pay/roi
    charge_mode             VARCHAR(16),       -- CPT/CPM/CPC/CPV/oCPM
    purpose_tag             VARCHAR(16),       -- exposure/seeding/conversion
    is_splittable           BOOLEAN DEFAULT TRUE -- 是否可拆分自然/付费
);

INSERT INTO dim_ad_product VALUES
    -- 巨量引擎品牌
    ('brand_zone',          '品牌专区',         'brand',   'ocean_engine', 'click',           'CPT/CPM',  'exposure/seeding', TRUE),
    ('brand_topview',       'TopView',         'brand',   'ocean_engine', 'impression',       'CPT/CPM',  'exposure',         TRUE),
    ('brand_feedslive',     'FeedsLive',       'brand',   'ocean_engine', 'live_enter',       'CPM',      'seeding/conversion', TRUE),
    ('brand_seeding_cpt',   '种草通合约',       'seeding', 'ocean_engine', 'engagement',       'CPT',      'seeding',          TRUE),
    ('brand_seeding_bid',   '种草通竞价',       'seeding', 'ocean_engine', 'engagement',       'oCPM',     'seeding',          TRUE),
    ('ad_feeds_bidding',    'AD竞价信息流',     'bidding', 'ocean_engine', 'multi',            'oCPM/CPC', 'exposure/seeding', TRUE),
    -- 原生内容加热
    ('native_douplus',      'DOU+',            'native',  'douyin_native','engagement',       'CPM',      'exposure/seeding/conversion', FALSE),
    ('native_shengliangbao','声量宝',           'native',  'ocean_engine', 'search_guide',     'CPM/CPT',  'seeding',          TRUE),
    ('native_xingzhitou',   '星智投',           'native',  'xingtu',       'play_guarantee',   'CPT',      'seeding',          FALSE),
    -- 千川
    ('qc_short_video',      '短视频引流',       'qianchuan','qianchuan',   'product_pay',      'oCPM',     'conversion',       TRUE),
    ('qc_live',             '直播引流',         'qianchuan','qianchuan',   'live_enter',       'oCPM',     'conversion',       TRUE),
    ('qc_product_card',     '商品卡',           'qianchuan','qianchuan',   'product_pay',      'oCPM',     'conversion',       TRUE),
    ('qc_unified',          '全域推广',         'qianchuan','qianchuan',   'roi',              'oCPM',     'conversion',       FALSE),
    ('qc_chengfang',        '乘方',             'qianchuan','qianchuan',   'roi',              'oCPM',     'conversion',       FALSE);


-- ============================================================
-- PART 3: 千川维度层
-- ============================================================

-- 3.1 千川广告计划维度表
CREATE TABLE dim_qianchuan_campaign (
    campaign_id             BIGINT PRIMARY KEY,
    advertiser_id           BIGINT NOT NULL,
    campaign_name           VARCHAR(256),
    product_type            VARCHAR(32) NOT NULL,  -- short_video/live/product_card
    delivery_mode           VARCHAR(32) NOT NULL,  -- standard/unified/chengfang
    optimize_goal           VARCHAR(64),            -- product_pay/roi/order_place/product_click/enter_live_room
    bid_strategy            VARCHAR(32),            -- cost_cap/max_conversion/auto_bid
    bid_amount              DECIMAL(12,2),
    budget_mode             VARCHAR(16),            -- daily/total/unlimited
    budget_amount           DECIMAL(14,2),
    schedule_start          DATETIME,
    schedule_end            DATETIME,
    status                  VARCHAR(16),            -- running/paused/ended/deleted
    is_splittable           BOOLEAN DEFAULT TRUE,   -- 标准推广=TRUE, 全域/乘方=FALSE
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);


-- 3.2 千川广告组维度表
CREATE TABLE dim_qianchuan_adgroup (
    adgroup_id              BIGINT PRIMARY KEY,
    campaign_id             BIGINT NOT NULL REFERENCES dim_qianchuan_campaign(campaign_id),
    adgroup_name            VARCHAR(256),
    -- 人群定向
    audience_type           VARCHAR(32),            -- universal/targeted/dmp/similar_creator
    audience_package_id     BIGINT,
    exclude_converted       BOOLEAN DEFAULT FALSE,
    -- 画像定向
    gender_target           VARCHAR(16),
    age_target              VARCHAR(128),
    region_target           TEXT,
    interest_target         TEXT,
    device_target           VARCHAR(64),
    -- 出价与预算
    bid_strategy            VARCHAR(32),
    bid_amount              DECIMAL(12,2),
    daily_budget            DECIMAL(14,2),
    status                  VARCHAR(16),
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);


-- 3.3 千川广告/创意维度表 (⭐ 星图缝合关键)
CREATE TABLE dim_qianchuan_ad (
    ad_id                   BIGINT PRIMARY KEY,
    adgroup_id              BIGINT NOT NULL REFERENCES dim_qianchuan_adgroup(adgroup_id),
    campaign_id             BIGINT NOT NULL REFERENCES dim_qianchuan_campaign(campaign_id),
    ad_name                 VARCHAR(256),
    -- 素材关联
    material_id             VARCHAR(64),            -- 千川素材ID
    material_type           VARCHAR(32),            -- video_authorized/video_self/image/live_screen
    material_source         VARCHAR(64),
    -- 星图缝合
    xingtu_video_id         VARCHAR(64),            -- ⭐ 缝合键
    creator_uid             VARCHAR(64),
    -- 创意形式
    creative_type           VARCHAR(32),            -- short_video_cart/image_cart/live_card/product_card
    -- 直播间
    live_room_id            VARCHAR(64),
    -- 归因
    attribution_window      INT DEFAULT 15,         -- 1/7/15/30 天
    status                  VARCHAR(16),
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_qad_xingtu_video ON dim_qianchuan_ad(xingtu_video_id) WHERE xingtu_video_id IS NOT NULL;
CREATE INDEX idx_qad_creator      ON dim_qianchuan_ad(creator_uid)      WHERE creator_uid IS NOT NULL;
CREATE INDEX idx_qad_material     ON dim_qianchuan_ad(material_id);
CREATE INDEX idx_qad_campaign     ON dim_qianchuan_ad(campaign_id);


-- 3.4 千川商品维度表
CREATE TABLE dim_qianchuan_product (
    qianchuan_product_id    BIGINT PRIMARY KEY,
    product_name            VARCHAR(256),
    product_image_url       VARCHAR(512),
    brand_sku_code          VARCHAR(64),
    luopan_spu_id           VARCHAR(64),
    luopan_sku_id           VARCHAR(64),
    category_level1         VARCHAR(64),
    category_level2         VARCHAR(64),
    category_level3         VARCHAR(64),
    price                   DECIMAL(10,2),
    commission_rate         DECIMAL(5,4),
    status                  VARCHAR(16),
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_qprod_brand_sku   ON dim_qianchuan_product(brand_sku_code) WHERE brand_sku_code IS NOT NULL;
CREATE INDEX idx_qprod_luopan_spu ON dim_qianchuan_product(luopan_spu_id)  WHERE luopan_spu_id IS NOT NULL;


-- 3.5 千川人群包维度表
CREATE TABLE dim_qianchuan_audience (
    audience_package_id     BIGINT PRIMARY KEY,
    audience_name           VARCHAR(256),
    audience_type           VARCHAR(32),            -- dmp_custom/dmp_rule/platform/creator_similar
    audience_source         VARCHAR(128),
    audience_size           BIGINT,
    reference_creator_uid   VARCHAR(64),            -- 达人相似人群包
    status                  VARCHAR(16),
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- PART 4: 星图内容表现层
-- ============================================================

-- 4.1 星图内容表现宽表 (基于真实 rawdata 校准)
CREATE TABLE xingtu_content_performance (
    xingtu_task_id          VARCHAR(64) PRIMARY KEY,
    video_id                VARCHAR(64) NOT NULL,
    creator_uid             VARCHAR(64) NOT NULL,
    creator_nickname        VARCHAR(128),
    mcn_id                  VARCHAR(64),
    mcn_name                VARCHAR(128),
    task_name               VARCHAR(256),
    task_type               VARCHAR(32),            -- 指派/招募
    task_status             VARCHAR(16),            -- 已完成/进行中
    video_title             VARCHAR(512),
    expect_publish_date     DATETIME,
    actual_publish_date     DATETIME,
    task_created_at         DATETIME,
    data_updated_at         DATETIME,

    -- 费用
    task_budget             DECIMAL(12,2),          -- 任务金额(达人固费)
    consumed_amount         DECIMAL(12,2),          -- 已消耗金额
    settled_amount          DECIMAL(12,2),          -- 实际结算金额
    ad_spend                DECIMAL(12,2),          -- 投放花费
    cpv                     DECIMAL(10,2),          -- 千次播放成本

    -- 播放量 (唯一可拆分维度)
    total_play              BIGINT,
    organic_play_cumulative BIGINT,                  -- 自然播放量-累计 (可为空)
    organic_play_settlement BIGINT,                  -- 自然播放量-结算周期

    -- 互动 (仅总量)
    total_likes             BIGINT,
    total_comments          BIGINT,
    total_shares            BIGINT,

    -- 组件 (仅总量, 挂车才有)
    component_impression    BIGINT,
    component_clicks        BIGINT,

    -- 评分
    overall_score           INT,                    -- 0-100
    spread_score            INT,
    seeding_score           INT,
    conversion_score        INT,

    -- 比率
    completion_rate         DECIMAL(8,6),           -- 视频完播率
    component_ctr           DECIMAL(8,6),           -- 组件点击率

    -- 频次触达
    reach_freq_1            BIGINT,
    reach_freq_2            BIGINT,
    reach_freq_3            BIGINT,
    reach_freq_4            BIGINT,
    reach_freq_5            BIGINT,
    reach_freq_6            BIGINT,
    reach_freq_7plus        BIGINT,

    -- 人群画像 (5组×7维, JSON存储, 不可拆分)
    audience_play           TEXT,                   -- 播放用户画像JSON
    audience_like           TEXT,                   -- 点赞用户画像JSON
    audience_comment        TEXT,                   -- 评论用户画像JSON
    audience_share          TEXT,                   -- 分享用户画像JSON
    audience_component      TEXT,                   -- 组件点击用户画像JSON

    -- 热词
    hotwords_brand          TEXT,
    hotwords_product        TEXT,
    hotwords_role           TEXT,
    hotwords_scene          TEXT,
    hotwords_comment        TEXT,
    sentiment               VARCHAR(64),            -- 正向:x%/负向:x%/中立:x%

    -- 回搜 (不可拆分)
    search_after_view_uv    BIGINT,
    search_after_view_pv    BIGINT,
    search_after_view_rate  DECIMAL(10,6),
    re_search_7d_pv         BIGINT,
    re_search_7d_uv         BIGINT,
    re_search_14d_pv        BIGINT,

    -- 罗盘回传转化 (不可拆分)
    direct_order_count      BIGINT,
    direct_gmv              DECIMAL(14,2),
    shop_visit_7d_uv        BIGINT,
    product_detail_7d_uv    BIGINT,
    add_cart_7d_uv          BIGINT,
    order_count_7d          BIGINT,

    -- 其他转化
    install_count           BIGINT,
    activate_count          BIGINT,
    pay_count               BIGINT,
    reserve_success         BIGINT,
    reserve_install         BIGINT,
    leads_count             BIGINT,

    -- 运维
    snapshot_date           DATE,                   -- 快照日期
    sync_batch_id           VARCHAR(64),
    created_at              TIMESTAMP DEFAULT NOW(),
    updated_at              TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_xcp_video       ON xingtu_content_performance(video_id);
CREATE INDEX idx_xcp_creator     ON xingtu_content_performance(creator_uid);
CREATE INDEX idx_xcp_publish     ON xingtu_content_performance(actual_publish_date);
CREATE INDEX idx_xcp_snapshot    ON xingtu_content_performance(snapshot_date);


-- ============================================================
-- PART 5: 事实表层
-- ============================================================

-- 5.1 千川按日投放事实表 (核心)
CREATE TABLE fact_qianchuan_daily (
    id                      BIGSERIAL,
    ad_id                   BIGINT NOT NULL,
    report_date             DATE NOT NULL,
    adgroup_id              BIGINT NOT NULL,
    campaign_id             BIGINT NOT NULL,
    material_id             VARCHAR(64),
    qianchuan_product_id    BIGINT,
    live_room_id            VARCHAR(64),

    -- 投放
    spend                   DECIMAL(14,4) DEFAULT 0,
    impression              BIGINT DEFAULT 0,
    click                   BIGINT DEFAULT 0,
    cpm                     DECIMAL(10,4),
    cpc                     DECIMAL(10,4),

    -- 播放 (短视频专用)
    video_play              BIGINT DEFAULT 0,
    valid_play              BIGINT DEFAULT 0,
    play_completion_rate    DECIMAL(8,6),
    avg_watch_duration      DECIMAL(10,2),

    -- 互动
    total_likes             BIGINT DEFAULT 0,
    total_comments          BIGINT DEFAULT 0,
    total_shares            BIGINT DEFAULT 0,
    total_engagement        BIGINT,
    engagement_rate         DECIMAL(8,6),
    cpe                     DECIMAL(10,4),

    -- 购物车
    cart_impression         BIGINT DEFAULT 0,
    cart_click              BIGINT DEFAULT 0,
    cart_ctr                DECIMAL(8,6),

    -- 直播 (直播专用)
    live_enter_uv           BIGINT DEFAULT 0,
    live_enter_rate         DECIMAL(8,6),
    live_avg_stay           DECIMAL(10,2),
    live_follow_count       BIGINT DEFAULT 0,

    -- 转化
    order_place             BIGINT DEFAULT 0,
    order_pay               BIGINT DEFAULT 0,
    gmv                     DECIMAL(14,2) DEFAULT 0,
    gpm                     DECIMAL(10,2),
    pay_rate                DECIMAL(8,6),

    -- ROI
    roi                     DECIMAL(10,4),
    cpa                     DECIMAL(10,4),

    -- 频控
    reach_uv                BIGINT DEFAULT 0,
    avg_frequency           DECIMAL(6,2),

    -- 全域标记
    is_unified              BOOLEAN DEFAULT FALSE,

    sync_batch_id           VARCHAR(64),
    created_at              TIMESTAMP DEFAULT NOW(),

    PRIMARY KEY (ad_id, report_date)
);
CREATE INDEX idx_fqd_date       ON fact_qianchuan_daily(report_date);
CREATE INDEX idx_fqd_campaign   ON fact_qianchuan_daily(campaign_id, report_date);
CREATE INDEX idx_fqd_material   ON fact_qianchuan_daily(material_id, report_date);
CREATE INDEX idx_fqd_live       ON fact_qianchuan_daily(live_room_id, report_date);


-- 5.2 千川直播场次事实表
CREATE TABLE fact_qianchuan_live_session (
    session_id              VARCHAR(64) PRIMARY KEY,
    live_room_id            VARCHAR(64) NOT NULL,
    campaign_id             BIGINT,
    session_start           DATETIME NOT NULL,
    session_end             DATETIME,
    session_duration        INT,
    live_room_type          VARCHAR(32),            -- brand_self/creator/mixed
    creator_uid             VARCHAR(64),

    total_spend             DECIMAL(14,4) DEFAULT 0,
    total_impression        BIGINT DEFAULT 0,
    total_enter_uv          BIGINT DEFAULT 0,
    enter_rate              DECIMAL(8,6),
    cpv                     DECIMAL(10,4),

    peak_online             BIGINT,
    avg_online              BIGINT,
    avg_stay_duration       DECIMAL(10,2),
    total_likes             BIGINT DEFAULT 0,
    total_comments          BIGINT DEFAULT 0,
    total_follow            BIGINT DEFAULT 0,
    follow_rate             DECIMAL(8,6),

    total_gmv               DECIMAL(14,2) DEFAULT 0,
    total_orders            BIGINT DEFAULT 0,
    gpm                     DECIMAL(10,2),
    roi                     DECIMAL(10,4),

    is_unified              BOOLEAN DEFAULT FALSE,
    created_at              TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_fqls_room_date ON fact_qianchuan_live_session(live_room_id, session_start);


-- 5.3 千川素材按日效果事实表 (素材生命周期/衰减分析)
CREATE TABLE fact_qianchuan_material_daily (
    material_id             VARCHAR(64) NOT NULL,
    report_date             DATE NOT NULL,
    ad_id                   BIGINT,

    spend                   DECIMAL(14,4) DEFAULT 0,
    impression              BIGINT DEFAULT 0,
    video_play              BIGINT DEFAULT 0,
    valid_play              BIGINT DEFAULT 0,
    click                   BIGINT DEFAULT 0,
    ctr                     DECIMAL(8,6),
    engagement              BIGINT DEFAULT 0,
    engagement_rate         DECIMAL(8,6),

    order_pay               BIGINT DEFAULT 0,
    gmv                     DECIMAL(14,2) DEFAULT 0,
    roi                     DECIMAL(10,4),
    gpm                     DECIMAL(10,2),

    decay_status            VARCHAR(16),            -- normal/warning/alert
    decay_pct               DECIMAL(6,4),

    sync_batch_id           VARCHAR(64),
    created_at              TIMESTAMP DEFAULT NOW(),

    PRIMARY KEY (material_id, report_date)
);
CREATE INDEX idx_fqmd_date   ON fact_qianchuan_material_daily(report_date);
CREATE INDEX idx_fqmd_decay  ON fact_qianchuan_material_daily(decay_status) WHERE decay_status IS NOT NULL;


-- 5.4 巨量引擎品牌广告按日事实表
CREATE TABLE fact_ocean_engine_daily (
    id                      BIGSERIAL,
    creative_id             VARCHAR(64) NOT NULL,
    report_date             DATE NOT NULL,
    campaign_id             VARCHAR(64),
    ad_product_type         VARCHAR(32) NOT NULL,   -- brand_zone/feeds_live/seeding_cpt/seeding_bidding/ad_feed/topview
    content_mapping_id      BIGINT REFERENCES dim_content_mapping(mapping_id),

    spend                   DECIMAL(14,4) DEFAULT 0,
    impression              BIGINT DEFAULT 0,
    click                   BIGINT DEFAULT 0,
    cpm                     DECIMAL(10,4),
    cpc                     DECIMAL(10,4),
    ctr                     DECIMAL(8,6),

    -- 播放
    video_play              BIGINT DEFAULT 0,
    completion_rate         DECIMAL(8,6),

    -- 互动
    total_engagement        BIGINT DEFAULT 0,
    engagement_rate         DECIMAL(8,6),
    cpe                     DECIMAL(10,4),
    comment_count           BIGINT DEFAULT 0,
    share_count             BIGINT DEFAULT 0,
    collect_count           BIGINT DEFAULT 0,

    -- 粉丝
    follow_count            BIGINT DEFAULT 0,
    cpf                     DECIMAL(10,4),

    -- 搜索 (品牌专区/声量宝)
    search_uv               BIGINT DEFAULT 0,
    search_pv               BIGINT DEFAULT 0,
    search_rate             DECIMAL(8,6),
    search_cost             DECIMAL(10,4),          -- 声量宝: consume/search_uv

    -- 直播 (FeedsLive)
    live_enter_uv           BIGINT DEFAULT 0,
    live_enter_rate         DECIMAL(8,6),
    live_avg_stay           DECIMAL(10,2),

    -- 频控
    reach_uv                BIGINT DEFAULT 0,
    avg_frequency           DECIMAL(6,2),
    non_fan_pct             DECIMAL(5,2),           -- 非粉触达占比

    -- 人群 (种草通)
    new_a1                  BIGINT DEFAULT 0,
    new_a2                  BIGINT DEFAULT 0,
    new_a3                  BIGINT DEFAULT 0,
    cpa3                    DECIMAL(10,4),

    sync_batch_id           VARCHAR(64),
    created_at              TIMESTAMP DEFAULT NOW(),

    PRIMARY KEY (creative_id, report_date)
);
CREATE INDEX idx_foe_date ON fact_ocean_engine_daily(report_date);


-- ============================================================
-- PART 6: 缝合宽表 (核心产出)
-- ============================================================

-- 6.1 千川-星图内容缝合宽表 (自然+付费+总体)
CREATE TABLE dws_content_qianchuan_stitched (
    xingtu_video_id         VARCHAR(64),
    qianchuan_ad_id         BIGINT,
    stitch_key_type         VARCHAR(32),            -- video_id/creator/estimated

    creator_uid             VARCHAR(64),
    creator_nickname        VARCHAR(128),
    video_title             VARCHAR(512),
    publish_date            DATE,
    campaign_purpose        VARCHAR(16),

    -- 自然流量 (来自星图)
    organic_play            BIGINT,
    organic_like            BIGINT,
    organic_comment         BIGINT,
    organic_share           BIGINT,
    organic_engagement      BIGINT,
    organic_engagement_rate DECIMAL(8,6),
    organic_search_uv       BIGINT,

    -- 付费投放 (来自千川)
    paid_spend              DECIMAL(14,4),
    paid_impression         BIGINT,
    paid_click              BIGINT,
    paid_play               BIGINT,
    paid_valid_play         BIGINT,
    paid_engagement         BIGINT,
    paid_engagement_rate    DECIMAL(8,6),
    paid_cart_click         BIGINT,
    paid_order_pay          BIGINT,
    paid_gmv                DECIMAL(14,2),

    -- 总体
    total_play              BIGINT,                 -- organic_play + paid_play
    total_engagement        BIGINT,
    total_gmv               DECIMAL(14,2),

    -- 投放效率
    paid_cpm                DECIMAL(10,4),
    paid_cpe                DECIMAL(10,4),
    paid_roi                DECIMAL(10,4),          -- 投放ROI = paid_gmv/paid_spend
    paid_cpa                DECIMAL(10,4),

    -- 衍生指标
    amplification_ratio      DECIMAL(6,2),          -- 投放杠杆倍数
    organic_contribution_pct DECIMAL(5,2),          -- 自然贡献率%
    heating_health_score    DECIMAL(6,4),           -- 加热健康度

    -- 标记
    stitch_quality          VARCHAR(16),            -- exact/estimated/unified_not_splittable
    is_unified              BOOLEAN DEFAULT FALSE,
    data_completeness       VARCHAR(16),            -- full/organic_only/paid_only

    -- 时间范围
    xingtu_snapshot_date    DATE,
    qianchuan_date_start    DATE,
    qianchuan_date_end      DATE,

    updated_at              TIMESTAMP DEFAULT NOW(),

    UNIQUE(xingtu_video_id, qianchuan_ad_id)
);
CREATE INDEX idx_dws_stitch_video    ON dws_content_qianchuan_stitched(xingtu_video_id);
CREATE INDEX idx_dws_stitch_creator  ON dws_content_qianchuan_stitched(creator_uid);
CREATE INDEX idx_dws_stitch_purpose  ON dws_content_qianchuan_stitched(campaign_purpose);


-- ============================================================
-- PART 7: 汇总宽表 (看板加速)
-- ============================================================

-- 7.1 千川汇总指标宽表 (campaign + 日期)
CREATE TABLE dws_qianchuan_metrics (
    report_date             DATE NOT NULL,
    campaign_id             BIGINT NOT NULL,

    product_type            VARCHAR(32),
    delivery_mode           VARCHAR(32),
    optimize_goal           VARCHAR(64),
    is_unified              BOOLEAN,
    is_splittable           BOOLEAN,

    total_spend             DECIMAL(14,4),
    total_impression        BIGINT,
    total_click             BIGINT,
    total_video_play        BIGINT,
    total_valid_play        BIGINT,
    total_engagement        BIGINT,
    total_cart_click        BIGINT,
    total_live_enter_uv     BIGINT,
    total_order_pay         BIGINT,
    total_gmv               DECIMAL(14,2),

    cpm                     DECIMAL(10,4),
    cpc                     DECIMAL(10,4),
    cpe                     DECIMAL(10,4),
    ctr                     DECIMAL(8,6),
    engagement_rate         DECIMAL(8,6),
    roi                     DECIMAL(10,4),
    gpm                     DECIMAL(10,2),
    cpa                     DECIMAL(10,4),
    pay_rate                DECIMAL(8,6),

    ad_count                INT,
    material_count          INT,

    PRIMARY KEY (report_date, campaign_id)
);


-- ============================================================
-- PART 8: 管理表
-- ============================================================

-- 8.1 星图快照版本表 (支持增量计算)
CREATE TABLE xingtu_snapshot_versions (
    version_id              BIGSERIAL PRIMARY KEY,
    snapshot_date           DATE NOT NULL,
    upload_id               BIGINT,
    content_count           INT,
    created_at              TIMESTAMP DEFAULT NOW(),
    UNIQUE(snapshot_date)
);


-- 8.2 数据上传日志表
CREATE TABLE data_upload_log (
    upload_id               BIGSERIAL PRIMARY KEY,
    file_name               VARCHAR(256) NOT NULL,
    file_hash               VARCHAR(64),
    data_source             VARCHAR(32) NOT NULL,   -- xingtu/qianchuan/ocean_engine/luopan/yuntu/douplus
    data_time_type          VARCHAR(16) NOT NULL,   -- cumulative/daily/periodic
    snapshot_date           DATE,
    date_range_start        DATE,
    date_range_end          DATE,
    row_count               INT,
    conflict_count          INT DEFAULT 0,
    status                  VARCHAR(16) DEFAULT 'pending',
    uploaded_by             VARCHAR(64),
    uploaded_at             TIMESTAMP DEFAULT NOW(),
    processed_at            TIMESTAMP
);


-- 8.3 数据质量校验记录表
CREATE TABLE data_quality_check (
    check_id                BIGSERIAL PRIMARY KEY,
    check_date              DATE NOT NULL,
    metric_name             VARCHAR(64) NOT NULL,
    source_a                VARCHAR(32) NOT NULL,
    source_b                VARCHAR(32) NOT NULL,
    value_a                 DECIMAL(16,2),
    value_b                 DECIMAL(16,2),
    diff_pct                DECIMAL(5,2),
    threshold               DECIMAL(5,2),
    status                  VARCHAR(16),            -- pass/warn/alert
    auto_resolved           BOOLEAN DEFAULT FALSE,
    user_choice             VARCHAR(32),
    resolved_at             TIMESTAMP,
    resolution_note         TEXT
);


-- 8.4 用户指标显隐偏好
CREATE TABLE user_metric_preference (
    id                      BIGSERIAL PRIMARY KEY,
    user_id                 VARCHAR(64) NOT NULL,
    page_name               VARCHAR(64) NOT NULL,   -- ceo/creator/content/qianchuan/brand_ad/native_heating/conversion/brand_asset
    metric_key              VARCHAR(64) NOT NULL,
    visible                 BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at              TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, page_name, metric_key)
);


-- 8.5 系统默认指标配置
CREATE TABLE system_metric_default (
    page_name               VARCHAR(64),
    metric_key              VARCHAR(64),
    display_level           VARCHAR(8),             -- locked/default_on/default_off
    display_order           INT,
    PRIMARY KEY(page_name, metric_key)
);


-- ============================================================
-- PART 9: 关键索引 & 注释
-- ============================================================

COMMENT ON TABLE dim_content_mapping IS '内容/素材ID映射表: 星图↔千川↔巨量引擎↔原生加热';
COMMENT ON TABLE dws_content_qianchuan_stitched IS '核心缝合宽表: 自然(星图) + 付费(千川) = 总体';
COMMENT ON TABLE fact_qianchuan_daily IS '千川按日投放事实表, 标准推广可拆分, 全域推广 is_unified=TRUE';
COMMENT ON TABLE fact_ocean_engine_daily IS '巨量引擎品牌广告按日事实表, 含品牌专区/种草通/FeedsLive/TopView/AD竞价';
COMMENT ON COLUMN dim_qianchuan_ad.xingtu_video_id IS '⭐ 与星图缝合的关键键, 授权素材时非空';
COMMENT ON COLUMN dim_qianchuan_campaign.delivery_mode IS 'standard-可拆分, unified/chengfang-不可拆分';
COMMENT ON COLUMN dim_qianchuan_campaign.product_type IS 'short_video-短视频, live-直播, product_card-商品卡';


-- ============================================================
-- ETL 示例: 缝合星图自然数据 + 千川付费数据
-- ============================================================

-- INSERT INTO dws_content_qianchuan_stitched
-- SELECT
--     cm.xingtu_video_id,
--     qa.ad_id,
--     'video_id' AS stitch_key_type,
--     xcp.creator_uid, xcp.creator_nickname, xcp.video_title,
--     xcp.actual_publish_date::DATE, 'seeding' AS campaign_purpose,
--     -- 自然
--     xcp.organic_play_cumulative, xcp.total_likes, xcp.total_comments, xcp.total_shares,
--     (COALESCE(xcp.total_likes,0)+COALESCE(xcp.total_comments,0)+COALESCE(xcp.total_shares,0)),
--     ROUND((COALESCE(xcp.total_likes,0)+COALESCE(xcp.total_comments,0)+COALESCE(xcp.total_shares,0))::NUMERIC / NULLIF(xcp.total_play,0), 6),
--     xcp.search_after_view_uv,
--     -- 付费
--     SUM(fqd.spend), SUM(fqd.impression), SUM(fqd.click), SUM(fqd.video_play),
--     SUM(fqd.valid_play), SUM(fqd.total_engagement),
--     ROUND(SUM(fqd.total_engagement)::NUMERIC / NULLIF(SUM(fqd.impression),0), 6),
--     SUM(fqd.cart_click), SUM(fqd.order_pay), SUM(fqd.gmv),
--     -- 总体
--     xcp.total_play + SUM(COALESCE(fqd.video_play,0)),
--     -- 投放效率
--     ROUND(SUM(fqd.spend)::NUMERIC * 1000 / NULLIF(SUM(fqd.impression),0), 4),
--     ROUND(SUM(fqd.spend)::NUMERIC / NULLIF(SUM(fqd.total_engagement),0), 4),
--     ROUND(SUM(fqd.gmv)::NUMERIC / NULLIF(SUM(fqd.spend),0), 4),
--     ROUND(SUM(fqd.spend)::NUMERIC / NULLIF(SUM(fqd.order_pay),0), 4),
--     -- 衍生
--     ROUND((xcp.organic_play_cumulative + SUM(COALESCE(fqd.video_play,0)))::NUMERIC / NULLIF(xcp.organic_play_cumulative,0), 2),
--     ROUND(xcp.organic_play_cumulative::NUMERIC * 100 / NULLIF(xcp.total_play,0), 2),
--     NULL,
--     'exact', FALSE, 'full',
--     xcp.snapshot_date, MIN(fqd.report_date), MAX(fqd.report_date)
-- FROM dim_content_mapping cm
-- JOIN xingtu_content_performance xcp ON cm.xingtu_video_id = xcp.video_id
-- JOIN dim_qianchuan_ad qa ON cm.qianchuan_mat_id = qa.material_id
-- JOIN fact_qianchuan_daily fqd ON qa.ad_id = fqd.ad_id
-- JOIN dim_qianchuan_campaign qc ON fqd.campaign_id = qc.campaign_id
-- WHERE qc.delivery_mode = 'standard'  -- 仅标准推广可拆分
-- GROUP BY cm.xingtu_video_id, qa.ad_id, xcp.*, xcp.snapshot_date;
