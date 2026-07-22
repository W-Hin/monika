-- MONIKA — Intelligent Mobile HR Management System
-- MySQL schema, Phase 2
--
-- Grounded in the existing Flutter models (lib/model/models.dart) and the
-- HR-configurable policy fields in lib/view/hr/policy/policy_config.dart —
-- not invented from the module list alone. Where the Dart layer stores a
-- display-only value (e.g. AppUser.employmentDuration, a formatted string
-- like "2 yrs 3 mos"), this schema stores the underlying fact instead
-- (hire_date) and leaves formatting/derivation to the application layer.
--
-- Import: phpMyAdmin > Import, or `mysql -u root monika < schema.sql`
-- (create the `monika` database first — see database/README.md)

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ─────────────────────────────────────────────────────────────────────────
-- Identity & Access
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE departments (
    id   INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE users (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    employee_code         VARCHAR(20) NOT NULL UNIQUE COMMENT 'display-facing id, e.g. EMP-1042 / HR-0007 — matches AppUser.id in the Flutter app',
    name                  VARCHAR(150) NOT NULL,
    email                 VARCHAR(150) NOT NULL UNIQUE,
    password_hash         VARCHAR(255) NOT NULL,
    user_role             ENUM('employee', 'hr_admin') NOT NULL,
    job_title             VARCHAR(100) NOT NULL,
    department_id         INT NOT NULL,
    avatar_initials       VARCHAR(4) NOT NULL,
    hire_date             DATE NOT NULL COMMENT 'source of truth; AppUser.employmentDuration is a formatted display of this',
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,

    -- Device binding — split into a display name (what the Flutter app
    -- currently shows, AppUser.registeredDevice) and a real binding token
    -- (not yet captured by the UI — clock_in.dart's 3-step check is
    -- currently simulated — but the IoT "device token binding match"
    -- check needs a real unique value once wired up in Phase 3).
    registered_device_name VARCHAR(100) NULL,
    device_token            VARCHAR(255) NULL,
    device_bound_at          DATETIME NULL,

    -- Running risk score. Scope: starts at 100, deducted per offence type
    -- (weights configurable via policy_settings). risk_level is a cached
    -- band derived from risk_score by the application layer, kept as a
    -- column so listing/sorting screens (hr_employees, hr_home) don't need
    -- to recompute it per row.
    risk_score            INT NOT NULL DEFAULT 100,
    risk_level             ENUM('low', 'medium', 'high') NOT NULL DEFAULT 'low',

    created_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (department_id) REFERENCES departments(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE password_reset_tokens (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    token_hash  VARCHAR(255) NOT NULL,
    expires_at  DATETIME NOT NULL,
    used_at     DATETIME NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────────────────
-- Attendance & Security (IoT triple-layer validation + risk/anomaly)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE attendance_records (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    work_date       DATE NOT NULL,
    clock_in_at     DATETIME NOT NULL,
    clock_out_at    DATETIME NULL,
    status          ENUM('on_time', 'late', 'flagged', 'leave') NOT NULL,
    flag_reason     VARCHAR(255) NULL,

    -- IoT triple-layer validation results (all 3 must pass per scope doc)
    gps_lat         DECIMAL(10, 7) NULL,
    gps_lng         DECIMAL(10, 7) NULL,
    gps_passed      BOOLEAN NOT NULL DEFAULT FALSE,
    wifi_ssid       VARCHAR(64) NULL,
    wifi_passed     BOOLEAN NOT NULL DEFAULT FALSE,
    device_passed   BOOLEAN NOT NULL DEFAULT FALSE,

    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_user_date (user_id, work_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE anomaly_events (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    user_id               INT NOT NULL,
    attendance_record_id  INT NULL COMMENT 'set when the anomaly originated from a specific clock-in attempt',
    type                  ENUM('out_of_zone', 'shared_device', 'late') NOT NULL,
    event_date            DATE NOT NULL,
    details               VARCHAR(255) NOT NULL,
    severity              ENUM('low', 'medium', 'high') NOT NULL,
    reviewed              BOOLEAN NOT NULL DEFAULT FALSE,
    reviewed_by           INT NULL,
    reviewed_at           DATETIME NULL,
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (attendance_record_id) REFERENCES attendance_records(id) ON DELETE SET NULL,
    FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────────────────
-- Leave & Payroll
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE leave_applications (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    reference_code VARCHAR(20) NOT NULL UNIQUE COMMENT 'display id, e.g. LV-2201',
    user_id       INT NOT NULL,
    leave_type    ENUM('annual', 'medical', 'emergency', 'unpaid') NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    days          INT NOT NULL,
    reason        VARCHAR(255) NOT NULL,
    status        ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
    decided_by    INT NULL,
    decided_at    DATETIME NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (decided_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE leave_balances (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL,
    year            YEAR NOT NULL,
    annual_total    INT NOT NULL DEFAULT 0,
    annual_used     INT NOT NULL DEFAULT 0,
    medical_total   INT NOT NULL DEFAULT 0,
    medical_used    INT NOT NULL DEFAULT 0,
    emergency_total INT NOT NULL DEFAULT 0,
    emergency_used  INT NOT NULL DEFAULT 0,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_user_year (user_id, year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payroll_summaries (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    user_id      INT NOT NULL,
    pay_month    DATE NOT NULL COMMENT 'stored as the 1st of the month, e.g. 2026-07-01',
    base_salary  DECIMAL(10, 2) NOT NULL,
    deductions   DECIMAL(10, 2) NOT NULL DEFAULT 0,
    net_pay      DECIMAL(10, 2) NOT NULL,
    generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_user_month (user_id, pay_month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE payroll_deduction_items (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    payroll_id  INT NOT NULL,
    label       VARCHAR(100) NOT NULL,
    amount      DECIMAL(10, 2) NOT NULL,

    FOREIGN KEY (payroll_id) REFERENCES payroll_summaries(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────────────────
-- Evaluation & Training
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE kpi_templates (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(150) NOT NULL,
    department_id  INT NULL COMMENT 'NULL = all departments, matches KpiTemplate.department "All Departments" sentinel in the Dart model',
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE kpi_template_items (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    template_id  INT NOT NULL,
    name         VARCHAR(150) NOT NULL,
    weightage    DECIMAL(5, 2) NOT NULL COMMENT 'percent; all items for one template must sum to 100 — enforced in application logic',

    FOREIGN KEY (template_id) REFERENCES kpi_templates(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE performance_evaluations (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    template_id    INT NULL COMMENT 'kept nullable — template may be edited/retired after this evaluation was scored',
    year           YEAR NOT NULL,
    comments       TEXT NULL,
    weighted_total DECIMAL(5, 2) NOT NULL COMMENT 'cached sum(score * weightage / 100); recomputed on save, matches PerformanceEvaluation.weightedTotal getter',
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (template_id) REFERENCES kpi_templates(id) ON DELETE SET NULL,
    UNIQUE KEY uniq_user_year (user_id, year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE performance_evaluation_scores (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    evaluation_id  INT NOT NULL,
    kpi_name       VARCHAR(150) NOT NULL,
    weightage      DECIMAL(5, 2) NOT NULL COMMENT 'snapshot of the weightage used at scoring time, independent of later template edits',
    score          DECIMAL(5, 2) NOT NULL COMMENT '0-100, matches KpiItem.score',

    FOREIGN KEY (evaluation_id) REFERENCES performance_evaluations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE training_programs (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    title                 VARCHAR(150) NOT NULL,
    category              ENUM('technical', 'behavioural', 'leadership') NOT NULL,
    description           TEXT NOT NULL,
    is_mandatory          BOOLEAN NOT NULL DEFAULT FALSE,
    duration              VARCHAR(50) NOT NULL COMMENT 'display string, e.g. "4 hours" — matches TrainingProgram.duration',
    department_id         INT NULL COMMENT 'NULL = all departments',
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE training_enrollments (
    id                     INT AUTO_INCREMENT PRIMARY KEY,
    program_id             INT NOT NULL,
    user_id                INT NOT NULL,
    is_recommended         BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'set by the ML/rule recommendation engine, Phase 5',
    recommendation_reason  VARCHAR(255) NULL,
    progress               DECIMAL(3, 2) NOT NULL DEFAULT 0 COMMENT '0.00-1.00, matches TrainingProgram.progress',
    is_completed           BOOLEAN NOT NULL DEFAULT FALSE,
    performance_score      DECIMAL(5, 2) NULL COMMENT '0-100, set once completed',
    enrolled_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at           DATETIME NULL,

    FOREIGN KEY (program_id) REFERENCES training_programs(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_program_user (program_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─────────────────────────────────────────────────────────────────────────
-- Config & Analytics
-- ─────────────────────────────────────────────────────────────────────────

-- Single-row table (id is always 1) holding every HR-configurable value
-- from policy_config.dart. A key-value table was considered but rejected —
-- this is a small, fixed set of fields the app already treats as a flat
-- settings form, so named columns keep it directly queryable/typed in PHP
-- without an extra unpack step.
CREATE TABLE policy_settings (
    id                     INT PRIMARY KEY DEFAULT 1,

    -- Risk score weights: points deducted per violation type
    late_weight            DECIMAL(4, 1) NOT NULL DEFAULT 1,
    out_of_zone_weight     DECIMAL(4, 1) NOT NULL DEFAULT 2,
    shared_device_weight   DECIMAL(4, 1) NOT NULL DEFAULT 3,

    -- Payroll deduction amounts (RM), applied at payroll computation time
    late_deduction         DECIMAL(10, 2) NOT NULL DEFAULT 25.00,
    absent_deduction       DECIMAL(10, 2) NOT NULL DEFAULT 120.00,

    -- Training trigger thresholds: PE category score below this recommends training
    leadership_threshold   DECIMAL(5, 2) NOT NULL DEFAULT 60,
    technical_threshold    DECIMAL(5, 2) NOT NULL DEFAULT 65,
    behavioural_threshold  DECIMAL(5, 2) NOT NULL DEFAULT 60,

    updated_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT single_row CHECK (id = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO policy_settings (id) VALUES (1);

-- Note: TeamMemberSummary.attendanceRate is deliberately NOT a stored
-- column anywhere — it's a derived aggregate (on-time attendance_records /
-- total attendance_records for a user) and should be computed by query in
-- the Analytics/Reporting endpoints, not cached, to avoid it drifting out
-- of sync with the underlying attendance_records rows.

SET FOREIGN_KEY_CHECKS = 1;
