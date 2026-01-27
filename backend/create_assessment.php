<?php
header('Content-Type: application/json');
include 'db.php';
include 'onesignal_helper.php';

$data = json_decode(file_get_contents('php://input'), true);

$title = $data['title'] ?? '';
$description = $data['description'] ?? '';
$ucode = $data['ucode'] ?? '';
$created_by = $data['created_by'] ?? '';
$categories = $data['categories'] ?? [];

if (empty($title) || empty($ucode) || empty($created_by)) {
    echo json_encode(["status" => "error", "message" => "Missing assessment data"]);
    exit;
}

$conn->begin_transaction();

try {
    // Check for existing assessment (Idempotency/Duplicate Prevention)
    $check = $conn->prepare("SELECT id FROM assessments WHERE ucode = ? AND created_by = ?");
    $check->bind_param("ss", $ucode, $created_by);
    $check->execute();
    $checkRes = $check->get_result();

    if ($checkRes->num_rows > 0) {
        // Assessment already exists, return existing ID
        $row = $checkRes->fetch_assoc();
        $assessment_id = $row['id'];
        // We assume details are already there or we don't want to duplicate them either.
        // Committing empty transaction just to be safe if we didn't do anything
        $conn->commit();
        echo json_encode(["status" => "success", "message" => "Assessment already exists (recovered)", "id" => $assessment_id]);
        exit;
    }
    $check->close();

    $stmt = $conn->prepare("INSERT INTO assessments (title, description, ucode, created_by) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("ssss", $title, $description, $ucode, $created_by);
    $stmt->execute();
    $assessment_id = $conn->insert_id;

    $stmtDetail = $conn->prepare("INSERT INTO assessment_details (assessment_id, category, marks, is_comment) VALUES (?, ?, ?, ?)");
    foreach ($categories as $cat) {
        $categoryName = $cat['name'];
        $marks = $cat['marks'] ?? 0;
        $isComment = $cat['is_comment'] ?? 0;
        $stmtDetail->bind_param("isii", $assessment_id, $categoryName, $marks, $isComment);
        $stmtDetail->execute();
    }

    $conn->commit();
    
    // Send push notification to all students
    try {
        notifyStudentsNewAssessment($title);
        error_log("Push notification sent for assessment: $title");
    } catch (Exception $e) {
        error_log("Failed to send push notification: " . $e->getMessage());
        // Don't fail the assessment creation if notification fails
    }
    
    echo json_encode(["status" => "success", "message" => "Assessment created successfully", "id" => $assessment_id]);
} catch (Exception $e) {
    $conn->rollback();
    echo json_encode(["status" => "error", "message" => "Failed to create assessment: " . $e->getMessage()]);
}

$stmt->close();
$conn->close();
?>
