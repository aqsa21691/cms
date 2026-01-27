<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

include "onesignal_helper.php";

// Enable error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);

$test_type = $data['test_type'] ?? 'all';
$external_id = $data['external_id'] ?? null;

error_log("🧪 TEST NOTIFICATION: Type=$test_type, External ID=$external_id");

$results = [];

// Test 1: Send to all students (by tag)
if ($test_type == 'all' || $test_type == 'students') {
    error_log("🧪 Sending test notification to ALL STUDENTS (by tag)");
    $result = notifyStudentsNewAssessment("TEST ASSESSMENT - Please Ignore");
    $results['students_by_tag'] = $result;
    error_log("🧪 Students notification result: " . json_encode($result));
}

// Test 2: Send to specific user by External ID
if ($test_type == 'all' || $test_type == 'specific') {
    if ($external_id) {
        error_log("🧪 Sending test notification to External ID: $external_id");
        $result = notifyTeacherEvaluation($external_id, "TEST_STUDENT", "TEST ASSESSMENT");
        $results['specific_user'] = $result;
        error_log("🧪 Specific user notification result: " . json_encode($result));
    } else {
        $results['specific_user'] = ['error' => 'No external_id provided'];
    }
}

// Test 3: Send to all subscribed users (broadcast)
if ($test_type == 'all' || $test_type == 'broadcast') {
    error_log("🧪 Sending BROADCAST test notification to ALL USERS");
    
    $fields = [
        'app_id' => ONESIGNAL_APP_ID,
        'headings' => ['en' => '🧪 Test Notification'],
        'contents' => ['en' => 'This is a test broadcast to all users. Please ignore.'],
        'included_segments' => ['All']  // Broadcast to everyone
    ];
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "https://onesignal.com/api/v1/notifications");
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json; charset=utf-8',
        'Authorization: Basic ' . ONESIGNAL_REST_API_KEY
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($fields));
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    
    $result = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    $response = json_decode($result, true);
    $results['broadcast'] = $response;
    error_log("🧪 Broadcast notification result ($httpCode): " . json_encode($response));
}

echo json_encode([
    'status' => 'success',
    'message' => 'Test notifications sent',
    'results' => $results
]);
?>
