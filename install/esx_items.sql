-- Native ESX inventory only, items(name, label, weight) schema. Do NOT import this with ox_inventory.
INSERT INTO items (name,label,weight) VALUES
('tv_remote','TV Remote',100)
ON DUPLICATE KEY UPDATE label=VALUES(label),weight=VALUES(weight);
