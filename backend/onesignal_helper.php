<?php
/**
 * OneSignal Helper for sending push notifications
 * 
 * SETUP INSTRUCTIONS:
 * 1. Go to OneSignal.com → Your App → Settings → Keys & IDs
 * 2. Copy your App ID and REST API Key
 * 3. Replace the placeholders below with your actual keys
 */

// OneSignal Configuration
define('ONESIGNAL_APP_ID', '384836b5-5495-4b82-8543-44c89468f73a');
define('ONESIGNAL_REST_API_KEY', 'os_v2_app_hbednnkusvfyfbkditeji2hxhicej43osjhettnz6lzgp7ikbraat3nzi7uvwbnzmk75zvmh75p5ivyrjw7d7urceewouk7z7dta5za');

/**
 * Send push notification via OneSignal
 * 
 * @param string $heading - Notification title
 * @param string $message - Notification message/body
 * @param array $filters - Targeting filters (field "tag") OR null if using external_ids
 * @param array $external_ids - Array of target user IDs OR null if using filters
 * @param array $data - Optional additional data payload
 * @return array - OneSignal API response
 */
function sendOneSignalNotification($heading, $message, $filters = null, $external_ids = null, $data = null) {
    if (!$filters && !$external_ids) {
        error_log("OneSignal Error: No targeting provided (filters or external_ids)");
        return ['success' => false, 'error' => 'No targeting provided'];
    }

    $fields = [
        'app_id' => ONESIGNAL_APP_ID,
        'headings' => ['en' => $heading],
        'contents' => ['en' => $message]
    ];
    
    if ($filters) {
        $fields['filters'] = $filters;
    }
    
    if ($external_ids) {
        $fields['include_external_user_ids'] = $external_ids;
    }

    // Add custom data if provided
    if ($data !== null) {
        $fields['data'] = $data;
    }
    
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
    
    if (curl_errno($ch)) {
        error_log("OneSignal cURL Error: " . curl_error($ch));
    }
    
    curl_close($ch);
    
    $response = json_decode($result, true);
    error_log("OneSignal Response ($httpCode): " . json_encode($response));
    
    return $response;
}

/**
 * Notify all students about new assessment
 */
function notifyStudentsNewAssessment($assessmentTitle) {
    $filters = [
        ["field" => "tag", "key" => "role", "relation" => "=", "value" => "student"]
    ];
    
    return sendOneSignalNotification(
        "📚 New Assessment Available!",
        "Assessment: $assessmentTitle",
        $filters,
        null, // No external IDs
        ['type' => 'new_assessment', 'title' => $assessmentTitle]
    );
}

/**
 * Notify teacher about submitted evaluation
 */
function notifyTeacherEvaluation($teacherId, $studentRoll, $assessmentTitle) {
    $teacherId = trim($teacherId);
    
    return sendOneSignalNotification(
        "✅ New Evaluation Submitted",
        "$studentRoll submitted evaluation for: $assessmentTitle",
        null,
        [$teacherId], // Target by External User ID
        ['type' => 'evaluation_submitted', 'student' => $studentRoll]
    );
}
?>
