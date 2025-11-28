/*
=============================================
HƯỚNG DẪN SAO LƯU & KHÔI PHỤC DATABASE
=============================================

LƯU Ý QUAN TRỌNG:
1. Đây là file tham khảo, KHÔNG TỰ ĐỘNG CHẠY
2. Copy từng đoạn lệnh để chạy thủ công trong SSMS
3. Thay đổi đường dẫn backup cho phù hợp với máy của bạn
4. Kiểm tra quyền truy cập thư mục trước khi chạy

CÁC LOẠI SAO LƯU:
- FULL BACKUP: Sao lưu toàn bộ database
- DIFFERENTIAL BACKUP: Chỉ sao lưu phần thay đổi kể từ lần Full Backup gần nhất
- TRANSACTION LOG BACKUP: Sao lưu log giao dịch (chỉ dùng khi recovery mode = FULL)
=============================================
*/

USE master;
GO

-- =============================================
-- PHẦN 1: SAO LƯU TOÀN BỘ (FULL BACKUP)
-- =============================================
-- Mô tả: Sao lưu toàn bộ database vào 1 file .bak
-- Khi nào dùng: Lần đầu tiên hoặc định kỳ hàng tuần
-- Kích thước: Lớn nhất (chứa toàn bộ dữ liệu)
-- =============================================

-- Cú pháp cơ bản
BACKUP DATABASE [BookstoreDb]
TO DISK = 'C:\SQLBackups\BookstoreDb_Full.bak'
WITH 
    NAME = 'BookstoreDb Full Backup',
    DESCRIPTION = 'Sao lưu toàn bộ database Bookstore',
    INIT,           -- Ghi đè file cũ
    STATS = 10;     -- Hiển thị % tiến trình

GO

-- Sao lưu với nén (giảm dung lượng file)
BACKUP DATABASE [BookstoreDb]
TO DISK = 'C:\SQLBackups\BookstoreDb_Full_Compressed.bak'
WITH 
    COMPRESSION,
    INIT,
    STATS = 10;

GO

-- Sao lưu với timestamp trong tên file (tránh ghi đè)
DECLARE @BackupFile NVARCHAR(500);
DECLARE @BackupName NVARCHAR(200);
SET @BackupFile = 'C:\SQLBackups\BookstoreDb_Full_' + 
                  FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.bak';
SET @BackupName = 'BookstoreDb Full Backup ' + FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm:ss');

BACKUP DATABASE [BookstoreDb]
TO DISK = @BackupFile
WITH 
    NAME = @BackupName,
    COMPRESSION,
    STATS = 10;

PRINT 'File backup đã tạo: ' + @BackupFile;
GO

-- =============================================
-- PHẦN 2: SAO LƯU SAI KHÁC (DIFFERENTIAL BACKUP)
-- =============================================
-- Mô tả: Chỉ sao lưu dữ liệu thay đổi kể từ lần Full Backup gần nhất
-- Khi nào dùng: Hàng ngày (giữa các lần Full Backup)
-- Kích thước: Nhỏ hơn Full Backup
-- Lưu ý: Phải có Full Backup trước đó
-- =============================================

BACKUP DATABASE [BookstoreDb]
TO DISK = 'C:\SQLBackups\BookstoreDb_Diff.bak'
WITH 
    DIFFERENTIAL,   -- Chỉ lấy phần thay đổi
    NAME = 'BookstoreDb Differential Backup',
    COMPRESSION,
    INIT,
    STATS = 10;

GO

-- =============================================
-- PHẦN 3: SAO LƯU NHẬT KÝ GIAO DỊCH (TRANSACTION LOG BACKUP)
-- =============================================
-- Mô tả: Sao lưu log các giao dịch để khôi phục đến thời điểm cụ thể
-- Khi nào dùng: Hàng giờ hoặc khi cần recovery chính xác
-- Điều kiện: Database phải ở FULL recovery mode
-- =============================================

-- Kiểm tra recovery mode hiện tại
SELECT name, recovery_model_desc 
FROM sys.databases 
WHERE name = 'BookstoreDb';
GO

-- Đổi sang FULL recovery mode (nếu cần)
ALTER DATABASE [BookstoreDb] SET RECOVERY FULL;
GO

-- Sao lưu transaction log
BACKUP LOG [BookstoreDb]
TO DISK = 'C:\SQLBackups\BookstoreDb_Log.trn'
WITH 
    NAME = 'BookstoreDb Transaction Log Backup',
    COMPRESSION,
    INIT,
    STATS = 10;

GO

-- =============================================
-- PHẦN 4: KHÔI PHỤC DATABASE (RESTORE)
-- =============================================
-- Lưu ý: RESTORE sẽ ghi đè database hiện tại!
-- Nên test trên database mới trước (đổi tên)
-- =============================================

-- 4.1. Khôi phục từ FULL BACKUP đơn giản
RESTORE DATABASE [BookstoreDb]
FROM DISK = 'C:\SQLBackups\BookstoreDb_Full.bak'
WITH 
    REPLACE,        -- Cho phép ghi đè database hiện có
    STATS = 10;

GO

-- 4.2. Khôi phục vào database mới (tránh ghi đè)
RESTORE DATABASE [BookstoreDb_Restored]
FROM DISK = 'C:\SQLBackups\BookstoreDb_Full.bak'
WITH 
    MOVE 'BookstoreDb' TO 'C:\SQLData\BookstoreDb_Restored.mdf',
    MOVE 'BookstoreDb_log' TO 'C:\SQLData\BookstoreDb_Restored_log.ldf',
    STATS = 10;

GO

-- 4.3. Khôi phục kết hợp Full + Differential
-- Bước 1: Restore Full Backup với NORECOVERY
RESTORE DATABASE [BookstoreDb_Restored]
FROM DISK = 'C:\SQLBackups\BookstoreDb_Full.bak'
WITH 
    MOVE 'BookstoreDb' TO 'C:\SQLData\BookstoreDb_Restored.mdf',
    MOVE 'BookstoreDb_log' TO 'C:\SQLData\BookstoreDb_Restored_log.ldf',
    NORECOVERY,     -- Cho phép apply thêm backup khác
    STATS = 10;

-- Bước 2: Restore Differential Backup với RECOVERY
RESTORE DATABASE [BookstoreDb_Restored]
FROM DISK = 'C:\SQLBackups\BookstoreDb_Diff.bak'
WITH 
    RECOVERY,       -- Hoàn tất quá trình restore
    STATS = 10;

GO

-- 4.4. Khôi phục đến thời điểm cụ thể (Point-in-Time Recovery)
-- Bước 1: Restore Full Backup
RESTORE DATABASE [BookstoreDb_Restored]
FROM DISK = 'C:\SQLBackups\BookstoreDb_Full.bak'
WITH 
    MOVE 'BookstoreDb' TO 'C:\SQLData\BookstoreDb_Restored.mdf',
    MOVE 'BookstoreDb_log' TO 'C:\SQLData\BookstoreDb_Restored_log.ldf',
    NORECOVERY,
    STATS = 10;

-- Bước 2: Restore Differential (nếu có)
RESTORE DATABASE [BookstoreDb_Restored]
FROM DISK = 'C:\SQLBackups\BookstoreDb_Diff.bak'
WITH 
    NORECOVERY,
    STATS = 10;

-- Bước 3: Restore Transaction Log đến thời điểm cụ thể
RESTORE LOG [BookstoreDb_Restored]
FROM DISK = 'C:\SQLBackups\BookstoreDb_Log.trn'
WITH 
    STOPAT = '2024-12-01 14:30:00',  -- Thời điểm muốn khôi phục
    RECOVERY,
    STATS = 10;

GO

-- =============================================
-- PHẦN 5: KIỂM TRA VÀ VERIFY BACKUP
-- =============================================

-- 5.1. Kiểm tra backup có hợp lệ không
RESTORE VERIFYONLY
FROM DISK = 'C:\SQLBackups\BookstoreDb_Full.bak';
GO

-- 5.2. Xem thông tin các file trong backup
RESTORE FILELISTONLY
FROM DISK = 'C:\SQLBackups\BookstoreDb_Full.bak';
GO

-- 5.3. Xem thông tin header của backup
RESTORE HEADERONLY
FROM DISK = 'C:\SQLBackups\BookstoreDb_Full.bak';
GO

-- 5.4. Xem lịch sử backup từ msdb
SELECT 
    database_name AS [Tên Database],
    CASE type
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Transaction Log'
    END AS [Loại Backup],
    backup_start_date AS [Ngày Bắt Đầu],
    backup_finish_date AS [Ngày Kết Thúc],
    backup_size / 1024 / 1024 AS [Kích Thước (MB)],
    physical_device_name AS [File Backup]
FROM msdb.dbo.backupset bs
INNER JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE database_name = 'BookstoreDb'
AND backup_start_date >= DATEADD(DAY, -30, GETDATE())
ORDER BY backup_start_date DESC;
GO

-- =============================================
-- PHẦN 6: CHIẾN LƯỢC SAO LƯU (BACKUP STRATEGY)
-- =============================================
/*
CHIẾN LƯỢC ĐỀ XUẤT CHO DỰ ÁN:

1. SAO LƯU HÀNG TUẦN:
   - Chạy Full Backup mỗi Chủ nhật 2:00 AM
   - Giữ lại file backup 1 tháng

2. SAO LƯU HÀNG NGÀY (nếu cần):
   - Chạy Differential Backup mỗi ngày (trừ Chủ nhật)
   - Giữ lại file backup 1 tuần

3. LƯU TRỮ:
   - Lưu backup ở ổ đĩa khác với database
   - Có thể copy sang USB hoặc cloud storage

VÍ DỤ LỊCH TRÌNH:
- Chủ nhật:  Full Backup
- Thứ 2-6:   Differential Backup
- Thứ 7:     Differential Backup + Kiểm tra backup

CHÚ Ý QUAN TRỌNG:
- Luôn TEST RESTORE trước khi cần dùng thật!
- Backup trước khi update/upgrade ứng dụng
- Kiểm tra dung lượng ổ đĩa trước khi backup
*/

-- =============================================
-- TÓM TẮT CÚ PHÁP QUAN TRỌNG
-- =============================================
PRINT '';
PRINT '=============================================';
PRINT 'CÁC LỆNH BACKUP CƠ BẢN:';
PRINT '=============================================';
PRINT '';
PRINT '1. FULL BACKUP:';
PRINT '   BACKUP DATABASE [BookstoreDb] TO DISK = ''path\file.bak''';
PRINT '';
PRINT '2. DIFFERENTIAL BACKUP:';
PRINT '   BACKUP DATABASE [BookstoreDb] TO DISK = ''path\file.bak'' WITH DIFFERENTIAL';
PRINT '';
PRINT '3. TRANSACTION LOG BACKUP:';
PRINT '   BACKUP LOG [BookstoreDb] TO DISK = ''path\file.trn''';
PRINT '';
PRINT '4. RESTORE:';
PRINT '   RESTORE DATABASE [BookstoreDb] FROM DISK = ''path\file.bak''';
PRINT '';
PRINT '5. VERIFY:';
PRINT '   RESTORE VERIFYONLY FROM DISK = ''path\file.bak''';
PRINT '';
PRINT '=============================================';
PRINT 'LƯU Ý: Thay đổi đường dẫn file cho phù hợp!';
PRINT '=============================================';
GO
