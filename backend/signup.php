<?php
header('Content-Type: application/json');
include 'db.php';

// Support raw JSON input
$input = json_decode(file_get_contents('php://input'), true);
$bgnu_id = $_POST['bgnu_id'] ?? $input['bgnu_id'] ?? '';
$full_name = $_POST['full_name'] ?? $input['full_name'] ?? '';
$password = $_POST['password'] ?? $input['password'] ?? '';
$designation = $_POST['designation'] ?? $input['designation'] ?? '';

if (empty($bgnu_id) || empty($full_name) || empty($password) || empty($designation)) {
    echo json_encode(["status" => "error", "message" => "All fields are mandatory"]);
    exit;
}

// Check if user already exists
$checkQuery = "SELECT bgnu_id FROM users WHERE bgnu_id = ?";
$stmt = $conn->prepare($checkQuery);
$stmt->bind_param("s", $bgnu_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo json_encode(["status" => "error", "message" => "User already exists"]);
    exit;
}

$insertQuery = "INSERT INTO users (bgnu_id, full_name, password, designation) VALUES (?, ?, ?, ?)";
$stmt = $conn->prepare($insertQuery);
$stmt->bind_param("ssss", $bgnu_id, $full_name, $password, $designation);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Account created successfully"]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to create account"]);
}

$stmt->close();
$conn->close();
?>
