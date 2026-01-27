<?php
header('Content-Type: application/json');
include 'db.php';

// Support raw JSON input
$input = json_decode(file_get_contents('php://input'), true);
$bgnu_id = $_POST['bgnu_id'] ?? $input['bgnu_id'] ?? '';
$password = $_POST['password'] ?? $input['password'] ?? '';

if (empty($bgnu_id) || empty($password)) {
    echo json_encode(["status" => "error", "message" => "All fields are mandatory"]);
    exit;
}

$query = "SELECT bgnu_id, full_name, designation FROM users WHERE bgnu_id = ? AND password = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("ss", $bgnu_id, $password);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $user = $result->fetch_assoc();
    echo json_encode([
        "status" => "success", 
        "message" => "Login successful",
        "user" => $user
    ]);
} else {
    echo json_encode(["status" => "error", "message" => "Invalid credentials"]);
}

$stmt->close();
$conn->close();
?>
