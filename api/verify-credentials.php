<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

// التحقق من أن الطلب هو POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

// قراءة البيانات المرسلة
$input = json_decode(file_get_contents('php://input'), true);

if (!$input || !isset($input['domain']) || !isset($input['secret']) || !isset($input['token'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Missing required fields']);
    exit;
}

$domain = $input['domain'];
$secret = $input['secret'];
$token = $input['token'];

// إعدادات قاعدة البيانات
$host = 'test.satayr.com';
$dbname = 'u897860000_ads';
$username = 'u897860000_ads';
$password = 'cB~s::9C';

try {
    // الاتصال بقاعدة البيانات
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // التحقق من البيانات
    $stmt = $pdo->prepare("SELECT `domain`, `secret` FROM `websites` WHERE `domain` = ? AND `secret` = ?");
    $stmt->execute([$domain, $secret]);
    
    if ($stmt->rowCount() > 0) {
        // التحقق من وجود التوكن في جدول devices
        $checkToken = $pdo->prepare("SELECT id FROM `devices` WHERE `domain` = ? AND `token` = ?");
        $checkToken->execute([$domain, $token]);
        
        if ($checkToken->rowCount() == 0) {
            // إدراج التوكن الجديد
            $insertToken = $pdo->prepare("INSERT INTO `devices`(`domain`, `token`) VALUES (?, ?)");
            $insertToken->execute([$domain, $token]);
            
            echo json_encode([
                'success' => true, 
                'message' => 'Credentials verified and token stored successfully',
                'token_stored' => true
            ]);
        } else {
            echo json_encode([
                'success' => true, 
                'message' => 'Credentials verified successfully',
                'token_stored' => false,
                'note' => 'Token already exists'
            ]);
        }
    } else {
        echo json_encode(['success' => false, 'message' => 'Invalid credentials']);
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Database connection failed: ' . $e->getMessage()]);
}
?> 