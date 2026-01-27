CREATE TABLE IF NOT EXISTS users (
    bgnu_id VARCHAR(50) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    password VARCHAR(255) NOT NULL,
    designation ENUM('Teacher', 'Student') NOT NULL
);

CREATE TABLE IF NOT EXISTS assessments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    ucode VARCHAR(4) NOT NULL,
    created_by VARCHAR(50),
    FOREIGN KEY (created_by) REFERENCES users(bgnu_id)
);

CREATE TABLE IF NOT EXISTS assessment_details (
    id INT AUTO_INCREMENT PRIMARY KEY,
    assessment_id INT,
    category VARCHAR(255) NOT NULL,
    marks INT DEFAULT 0,
    is_comment BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS evaluations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    assessment_id INT,
    category_id INT,
    marks INT DEFAULT 0,
    comment TEXT,
    evaluated_by VARCHAR(50),
    evaluation_of VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (assessment_id) REFERENCES assessments(id),
    FOREIGN KEY (category_id) REFERENCES assessment_details(id),
    FOREIGN KEY (evaluated_by) REFERENCES users(bgnu_id),
    FOREIGN KEY (evaluation_of) REFERENCES users(bgnu_id)
);
