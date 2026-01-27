<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");

// Handle preflight
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

include "db.php";
include "onesignal_helper.php";

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);

// Log the incoming request
error_log("Received evaluation data: " . $raw);

if (!$data) {
    echo json_encode(["status" => "error", "message" => "No data or invalid JSON provided"]);
    exit;
}

$assessment_id = $data['assessment_id'] ?? '';
$student_roll = $data['student_roll'] ?? '';  // This is evaluation_of
$evaluated_by = $data['evaluated_by'] ?? '';
$device_id = $data['device_id'] ?? '';
$client_time = $data['created_at'] ?? date('Y-m-d H:i:s'); // Use client-provided timestamp
$items = $data['data'] ?? [];

if (empty($assessment_id) || empty($student_roll) || empty($evaluated_by)) {
    echo json_encode(["status" => "error", "message" => "Mandatory fields missing (assessment_id, student_roll, or evaluated_by)"]);
    exit;
}

$conn->begin_transaction();

try {
    // Check for duplicate evaluation using the exact client timestamp
    // This allows re-evaluating later but prevents double-syncing the same attempt
    $checkStmt = $conn->prepare("SELECT id FROM evaluations WHERE assessment_id = ? AND evaluation_of = ? AND created_at = ?");
    $checkStmt->bind_param("iss", $assessment_id, $student_roll, $client_time);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();

    if ($checkResult->num_rows > 0) {
        $row = $checkResult->fetch_assoc();
        echo json_encode(["status" => "success", "message" => "Evaluation already synced (idempotent)", "id" => $row['id']]);
        $conn->rollback();
        exit;
    }
    $checkStmt->close();

    // Insert with the original timestamp from the phone
    $stmt = $conn->prepare("INSERT INTO evaluations (assessment_id, category_id, marks, comment, evaluated_by, evaluation_of, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)");
    
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }

    foreach ($items as $item) {
        $cat_id = $item['category_id'] ?? 0;
        $marks = $item['marks'] ?? 0;
        $comment = $item['comment'] ?? '';
        
        // assessment_id(i), category_id(i), marks(i), comment(s), evaluated_by(s), evaluation_of(s), created_at(s)
        $stmt->bind_param("iiissss", $assessment_id, $cat_id, $marks, $comment, $evaluated_by, $student_roll, $client_time);
        
        if (!$stmt->execute()) {
            throw new Exception("Execute failed: " . $stmt->error);
        }
    }

    $conn->commit();
    
    // Get the last inserted ID (from the first item insert)
    $evaluation_id = $conn->insert_id;
    
    // Fetch teacher ID and assessment title for notification
    try {
        $getTeacherStmt = $conn->prepare("SELECT created_by, title FROM assessments WHERE id = ?");
        $getTeacherStmt->bind_param("i", $assessment_id);
        $getTeacherStmt->execute();
        $result = $getTeacherStmt->get_result();
        
        if ($row = $result->fetch_assoc()) {
            $teacherId = $row['created_by'];
            $assessmentTitle = $row['title'];
            
            error_log("📤 Attempting to send notification to teacher: $teacherId for assessment: $assessmentTitle");
            
            // Send push notification to teacher
            $notificationResult = notifyTeacherEvaluation($teacherId, $student_roll, $assessmentTitle);
            
            if ($notificationResult && isset($notificationResult['id'])) {
                error_log("✅ Push notification sent successfully! Notification ID: " . $notificationResult['id']);
            } else {
                error_log("⚠️ Push notification failed or returned no ID. Response: " . json_encode($notificationResult));
            }
        } else {
            error_log("⚠️ Could not find assessment with ID: $assessment_id for notification");
        }
        
        $getTeacherStmt->close();
    } catch (Exception $e) {
        error_log("❌ Failed to send push notification: " . $e->getMessage());
        // Don't fail evaluation if notification fails
    }
    
    echo json_encode([
        "status" => "success", 
        "message" => "Evaluation submitted successfully",
        "id" => $evaluation_id
    ]);
    error_log("✅ Evaluation submitted successfully for student: $student_roll with ID: $evaluation_id");
} catch (Exception $e) {
    if (isset($conn) && $conn->ping()) $conn->rollback();
    $errorMsg = "Failed to submit evaluation: " . $e->getMessage();
    error_log($errorMsg);
    echo json_encode(["status" => "error", "message" => $errorMsg]);
}

if (isset($stmt)) $stmt->close();
$conn->close();
?>
