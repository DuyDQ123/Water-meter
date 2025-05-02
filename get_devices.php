<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$servername = "localhost";
$username = "root";
$password = "";
$dbname = "test";

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    http_response_code(500);
    die(json_encode(['error' => 'Database connection failed: ' . $conn->connect_error]));
}

try {
    // For debugging
    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

    // 1. Get base device info
    $devices = [];
    $sql = "SELECT * FROM devices";
    $result = $conn->query($sql);
    
    if ($result === FALSE) {
        throw new Exception("Error getting devices: " . $conn->error);
    }

    while ($device = $result->fetch_assoc()) {
        $device_id = $device['id'];
        
        // 2. Get latest OCR for this device
        $sql_ocr = "SELECT ocr_text, timestamp 
                    FROM ocr_results 
                    WHERE device_id = $device_id 
                    ORDER BY timestamp DESC 
                    LIMIT 1";
        $ocr_result = $conn->query($sql_ocr)->fetch_assoc();

        // 3. Get latest bill for this device
        $sql_bill = "SELECT amount, created_at 
                     FROM water_bills 
                     WHERE device_id = $device_id 
                     ORDER BY created_at DESC 
                     LIMIT 1";
        $bill_result = $conn->query($sql_bill)->fetch_assoc();

        // Combine all data
        $devices[] = [
            'id' => $device['id'],
            'name' => $device['name'],
            'location_lat' => $device['location_lat'] ? floatval($device['location_lat']) : null,
            'location_lng' => $device['location_lng'] ? floatval($device['location_lng']) : null,
            'last_reading' => $ocr_result ? $ocr_result['ocr_text'] : null,
            'last_update' => $ocr_result ? $ocr_result['timestamp'] : null,
            'last_bill_amount' => $bill_result ? floatval($bill_result['amount']) : null,
            'bill_date' => $bill_result ? $bill_result['created_at'] : null,
            'debug_info' => [
                'has_ocr' => !empty($ocr_result),
                'has_bill' => !empty($bill_result),
                'sql_ocr' => $sql_ocr,
                'sql_bill' => $sql_bill
            ]
        ];
    }

    echo json_encode([
        'success' => true,
        'devices' => $devices,
        'debug' => [
            'sql_base' => $sql,
            'device_count' => count($devices),
            'mysql_version' => mysqli_get_server_info($conn)
        ]
    ], JSON_PRETTY_PRINT);

} catch (Exception $e) {
    error_log("get_devices.php error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'error' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ], JSON_PRETTY_PRINT);
}

$conn->close();
?>