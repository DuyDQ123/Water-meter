<?php
 = 'localhost';
 = 'root';
 = '';
 = 'test';

 = new mysqli(, , , );

if (->connect_error) {
    die('Connection failed: ' . ->connect_error);
}

// Create table if not exists
 = 'CREATE TABLE IF NOT EXISTS dht_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    temperature FLOAT NOT NULL,
    humidity FLOAT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
)';

->query();

// Insert test data
 = [
    [25.5, 65.2],
    [26.1, 64.8],
    [25.8, 65.5],
    [26.3, 64.1],
    [25.9, 65.7]
];

 = ->prepare('INSERT INTO dht_data (temperature, humidity) VALUES (?, ?)');

foreach ( as ) {
    ->bind_param('dd', [0], [1]);
    ->execute();
}

->close();
->close();

echo 'Test data inserted successfully!';
?>
