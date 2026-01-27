<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: GET, OPTIONS");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

include "onesignal_helper.php";

error_reporting(E_ALL);
ini_set('display_errors', 1);

$diagnostics = [];

// 1. Verify OneSignal Credentials
$diagnostics['credentials'] = [
    'app_id' => ONESIGNAL_APP_ID,
    'api_key_length' => strlen(ONESIGNAL_REST_API_KEY),
    'api_key_prefix' => substr(ONESIGNAL_REST_API_KEY, 0, 10) . '...',
];

// 2. Test OneSignal API Connection
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, "https://onesignal.com/api/v1/apps/" . ONESIGNAL_APP_ID);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Basic ' . ONESIGNAL_REST_API_KEY
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

$result = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$appInfo = json_decode($result, true);

$diagnostics['api_connection'] = [
    'http_code' => $httpCode,
    'status' => $httpCode == 200 ? 'SUCCESS' : 'FAILED',
    'app_name' => $appInfo['name'] ?? 'N/A',
    'total_users' => $appInfo['players'] ?? 0,
];

// 3. Get All Subscribed Users
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, "https://onesignal.com/api/v1/players?app_id=" . ONESIGNAL_APP_ID . "&limit=300");
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Authorization: Basic ' . ONESIGNAL_REST_API_KEY
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

$result = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$playersData = json_decode($result, true);
$players = $playersData['players'] ?? [];

$diagnostics['subscribed_users'] = [
    'total_count' => count($players),
    'users' => []
];

foreach ($players as $player) {
    $userData = [
        'external_id' => $player['external_user_id'] ?? 'NOT_SET',
        'tags' => $player['tags'] ?? [],
        'last_active' => $player['last_active'] ?? 'N/A',
        'notification_types' => $player['notification_types'] ?? 0,
    ];
    $diagnostics['subscribed_users']['users'][] = $userData;
}

// 4. Count users by role
$teachers = 0;
$students = 0;
$no_role = 0;

foreach ($players as $player) {
    $role = $player['tags']['role'] ?? null;
    if ($role == 'teacher') $teachers++;
    elseif ($role == 'student') $students++;
    else $no_role++;
}

$diagnostics['user_breakdown'] = [
    'teachers' => $teachers,
    'students' => $students,
    'no_role_tag' => $no_role,
];

// 5. Test Notification Send (to all users)
$testFields = [
    'app_id' => ONESIGNAL_APP_ID,
    'headings' => ['en' => '🔔 Diagnostic Test'],
    'contents' => ['en' => 'OneSignal is working! This is an automated test.'],
    'included_segments' => ['All']
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, "https://onesignal.com/api/v1/notifications");
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json; charset=utf-8',
    'Authorization: Basic ' . ONESIGNAL_REST_API_KEY
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($testFields));
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

$result = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$notificationResult = json_decode($result, true);

$diagnostics['test_notification'] = [
    'http_code' => $httpCode,
    'status' => $httpCode == 200 ? 'SENT' : 'FAILED',
    'notification_id' => $notificationResult['id'] ?? 'N/A',
    'recipients' => $notificationResult['recipients'] ?? 0,
    'errors' => $notificationResult['errors'] ?? [],
];

// 6. Summary and Recommendations
$diagnostics['summary'] = [
    'api_working' => $httpCode == 200,
    'users_subscribed' => count($players) > 0,
    'tags_configured' => ($teachers + $students) > 0,
    'test_sent' => isset($notificationResult['id']),
];

$diagnostics['recommendations'] = [];

if ($httpCode != 200) {
    $diagnostics['recommendations'][] = '❌ OneSignal API credentials are incorrect. Check App ID and REST API Key.';
}

if (count($players) == 0) {
    $diagnostics['recommendations'][] = '⚠️ No users subscribed to OneSignal. Users must login to the app at least once.';
}

if ($no_role > 0) {
    $diagnostics['recommendations'][] = "⚠️ $no_role users have no role tag. Check signin_screen.dart OneSignal.User.addTags() implementation.";
}

if (($notificationResult['recipients'] ?? 0) == 0) {
    $diagnostics['recommendations'][] = '⚠️ Test notification sent but no recipients. Check if users have notifications enabled on their devices.';
}

if (empty($diagnostics['recommendations'])) {
    $diagnostics['recommendations'][] = '✅ Everything looks good! Notifications should be working.';
}

echo json_encode($diagnostics, JSON_PRETTY_PRINT);
?>
