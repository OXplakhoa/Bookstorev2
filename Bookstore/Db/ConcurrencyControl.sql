/*
=============================================
GIAO DỊCH VÀ KIỂM SOÁT ĐỒNG THỜI - BOOKSTORE
=============================================

LƯU Ý QUAN TRỌNG:
1. Đây là file tham khảo về TRANSACTION và CONCURRENCY CONTROL
2. Các ví dụ được đơn giản hóa để dễ hiểu
3. Nên chạy từng ví dụ một để quan sát kết quả
4. Entity Framework đã tự động xử lý phần lớn các vấn đề concurrency

CÁC KHÁI NIỆM CHÍNH:
- TRANSACTION: Nhóm các câu lệnh SQL thành một đơn vị công việc
- COMMIT: Lưu các thay đổi vào database
- ROLLBACK: Hủy bỏ các thay đổi khi có lỗi
- LOCK: Khóa dữ liệu để tránh xung đột khi nhiều user cùng truy cập
=============================================
*/

USE BookstoreDb;
GO

-- =============================================
-- PHẦN 1: TRANSACTION CỞ BẢN (CƠ CHẾ GIAO DỊCH)
-- =============================================

-- 1.1. Transaction đơn giản - Cập nhật giá sản phẩm
-- Mô tả: Nếu thành công thì COMMIT, nếu lỗi thì ROLLBACK

BEGIN TRANSACTION;

    -- Cập nhật giá sản phẩm
    UPDATE dbo.Products
    SET Price = Price * 1.1  -- Tăng giá 10%
    WHERE CategoryId = 1;
    
    -- Kiểm tra số dòng bị ảnh hưởng
    IF @@ROWCOUNT > 0
    BEGIN
        PRINT N'Cập nhật giá thành công cho ' + CAST(@@ROWCOUNT AS NVARCHAR(10)) + N' sản phẩm';
        COMMIT TRANSACTION;  -- Lưu thay đổi
    END
    ELSE
    BEGIN
        PRINT N'Không có sản phẩm nào được cập nhật';
        ROLLBACK TRANSACTION;  -- Hủy thay đổi
    END

GO

-- 1.2. Transaction với TRY-CATCH (Xử lý lỗi)
-- Mô tả: Tự động ROLLBACK khi có lỗi

BEGIN TRY
    BEGIN TRANSACTION;
    
        -- Bước 1: Trừ tiền trong tài khoản (giả sử có bảng này)
        DECLARE @UserId NVARCHAR(450) = 'user-id-example';
        DECLARE @Amount DECIMAL(18,2) = 100000;
        
        -- Bước 2: Tạo đơn hàng
        INSERT INTO dbo.Orders (UserId, OrderDate, Total, OrderStatus, PaymentStatus)
        VALUES (@UserId, GETUTCDATE(), @Amount, 'Pending', 'Paid');
        
        DECLARE @NewOrderId INT = SCOPE_IDENTITY();
        
        -- Bước 3: Thêm chi tiết đơn hàng
        INSERT INTO dbo.OrderItems (OrderId, ProductId, Quantity, UnitPrice)
        VALUES (@NewOrderId, 1, 2, 50000);
        
        PRINT N'Tạo đơn hàng thành công: OrderId = ' + CAST(@NewOrderId AS NVARCHAR(10));
        
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- Có lỗi xảy ra, hủy toàn bộ transaction
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    PRINT N'LỖI: ' + ERROR_MESSAGE();
END CATCH
GO

-- 1.3. Transaction với nhiều bước (Đặt hàng)
-- Mô tả: Tạo Order + OrderItems + Trừ Stock trong một giao dịch

BEGIN TRY
    BEGIN TRANSACTION;
    
        DECLARE @UserId NVARCHAR(450) = (SELECT TOP 1 Id FROM dbo.AspNetUsers WHERE Email LIKE '%customer%');
        DECLARE @ProductId INT = 1;
        DECLARE @Quantity INT = 2;
        DECLARE @ProductPrice DECIMAL(18,2);
        DECLARE @CurrentStock INT;
        
        -- Bước 1: Kiểm tra tồn kho
        SELECT @ProductPrice = Price, @CurrentStock = Stock
        FROM dbo.Products
        WHERE ProductId = @ProductId AND IsActive = 1;
        
        IF @CurrentStock IS NULL OR @CurrentStock < @Quantity
        BEGIN
            RAISERROR(N'Sản phẩm không đủ hàng', 16, 1);
        END
        
        -- Bước 2: Tạo đơn hàng
        INSERT INTO dbo.Orders (
            UserId, OrderDate, Total, ShippingName, ShippingPhone, 
            ShippingAddress, PaymentMethod, PaymentStatus, OrderStatus
        )
        VALUES (
            @UserId, GETUTCDATE(), @ProductPrice * @Quantity,
            N'Nguyễn Văn A', '0123456789', N'123 Đường ABC, TP.HCM',
            'COD', 'COD', 'Pending'
        );
        
        DECLARE @OrderId INT = SCOPE_IDENTITY();
        
        -- Bước 3: Thêm chi tiết đơn hàng
        INSERT INTO dbo.OrderItems (OrderId, ProductId, Quantity, UnitPrice)
        VALUES (@OrderId, @ProductId, @Quantity, @ProductPrice);
        
        -- Bước 4: Trừ tồn kho
        UPDATE dbo.Products
        SET Stock = Stock - @Quantity
        WHERE ProductId = @ProductId;
        
        PRINT N'Đặt hàng thành công! OrderId = ' + CAST(@OrderId AS NVARCHAR(10));
        
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    PRINT N'Đặt hàng thất bại: ' + ERROR_MESSAGE();
END CATCH
GO

-- =============================================
-- PHẦN 2: KHÓA DỮ LIỆU (LOCKING)
-- =============================================

-- 2.1. UPDLOCK - Khóa để chuẩn bị cập nhật (tránh race condition)
-- Mô tả: Khóa dòng khi đọc để đảm bảo không ai thay đổi trước khi update

BEGIN TRANSACTION;

    DECLARE @ProductId INT = 1;
    DECLARE @CurrentStock INT;
    DECLARE @OrderQuantity INT = 5;
    
    -- Đọc Stock với UPDLOCK (khóa dòng để update)
    SELECT @CurrentStock = Stock
    FROM dbo.Products WITH (UPDLOCK)
    WHERE ProductId = @ProductId;
    
    PRINT N'Tồn kho hiện tại: ' + CAST(@CurrentStock AS NVARCHAR(10));
    
    -- Kiểm tra đủ hàng không
    IF @CurrentStock >= @OrderQuantity
    BEGIN
        -- Cập nhật Stock
        UPDATE dbo.Products
        SET Stock = Stock - @OrderQuantity
        WHERE ProductId = @ProductId;
        
        PRINT N'Trừ kho thành công! Còn lại: ' + CAST(@CurrentStock - @OrderQuantity AS NVARCHAR(10));
        COMMIT TRANSACTION;
    END
    ELSE
    BEGIN
        PRINT N'Không đủ hàng! Cần: ' + CAST(@OrderQuantity AS NVARCHAR(10)) + 
              N', Có: ' + CAST(@CurrentStock AS NVARCHAR(10));
        ROLLBACK TRANSACTION;
    END

GO

-- 2.2. HOLDLOCK - Giữ khóa đến khi transaction kết thúc
-- Mô tả: Kết hợp UPDLOCK + HOLDLOCK để khóa chặt chẽ hơn

BEGIN TRANSACTION;

    -- Khóa sản phẩm để đảm bảo không ai thay đổi
    DECLARE @ProductId INT = 1;
    DECLARE @Stock INT;
    
    SELECT @Stock = Stock
    FROM dbo.Products WITH (UPDLOCK, HOLDLOCK)
    WHERE ProductId = @ProductId;
    
    PRINT N'Đang xử lý sản phẩm có Stock = ' + CAST(@Stock AS NVARCHAR(10));
    
    -- Giả lập xử lý lâu (3 giây)
    -- WAITFOR DELAY '00:00:03';
    
    -- Cập nhật stock
    UPDATE dbo.Products
    SET Stock = Stock - 1
    WHERE ProductId = @ProductId;
    
    COMMIT TRANSACTION;

GO

-- 2.3. NOLOCK - Đọc dữ liệu không cần chờ (dirty read)
-- Mô tả: Đọc nhanh nhưng có thể đọc dữ liệu chưa commit (không khuyến khích)

-- Ví dụ: Đọc danh sách sản phẩm cho dashboard (không cần chính xác tuyệt đối)
SELECT 
    ProductId,
    Title,
    Price,
    Stock
FROM dbo.Products WITH (NOLOCK)
WHERE IsActive = 1;

GO

-- =============================================
-- PHẦN 3: DEADLOCK VÀ CÁCH TRÁNH
-- =============================================

-- 3.1. Tình huống gây Deadlock
-- Mô tả: 2 transaction khóa theo thứ tự khác nhau → bế tắc

/*
DEADLOCK XẢY RA KHI:

Session 1:
BEGIN TRAN
UPDATE Products SET Stock = 100 WHERE ProductId = 1  -- Khóa Product 1
-- Chờ 5 giây
UPDATE Orders SET Total = 200 WHERE OrderId = 1      -- Cần khóa Order 1

Session 2:
BEGIN TRAN
UPDATE Orders SET Total = 300 WHERE OrderId = 1      -- Khóa Order 1
-- Chờ 5 giây  
UPDATE Products SET Stock = 50 WHERE ProductId = 1   -- Cần khóa Product 1

→ SQL Server sẽ chọn 1 transaction để ROLLBACK (deadlock victim)
*/

-- 3.2. Cách tránh Deadlock: Khóa theo thứ tự nhất quán
-- Mô tả: Luôn khóa các bảng theo cùng một thứ tự

BEGIN TRANSACTION;

    -- Luôn khóa Products trước, Orders sau
    UPDATE dbo.Products WITH (UPDLOCK)
    SET Stock = Stock - 1
    WHERE ProductId = 1;
    
    UPDATE dbo.Orders WITH (UPDLOCK)
    SET Total = Total + 100
    WHERE OrderId = 1;
    
COMMIT TRANSACTION;

GO

-- 3.3. Xử lý Deadlock với TRY-CATCH và Retry
-- Mô tả: Tự động thử lại khi bị deadlock

DECLARE @MaxRetries INT = 3;
DECLARE @RetryCount INT = 0;
DECLARE @Success BIT = 0;

WHILE @RetryCount < @MaxRetries AND @Success = 0
BEGIN
    SET @RetryCount = @RetryCount + 1;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
            -- Cập nhật stock
            UPDATE dbo.Products
            SET Stock = Stock - 1
            WHERE ProductId = 1;
            
            -- Cập nhật order
            UPDATE dbo.Orders
            SET Total = Total + 100
            WHERE OrderId = 1;
            
        COMMIT TRANSACTION;
        SET @Success = 1;
        PRINT N'Thành công!';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Kiểm tra có phải deadlock không (Error 1205)
        IF ERROR_NUMBER() = 1205
        BEGIN
            PRINT N'Deadlock xảy ra! Thử lại lần ' + CAST(@RetryCount AS NVARCHAR(10));
            WAITFOR DELAY '00:00:01';  -- Chờ 1 giây rồi thử lại
        END
        ELSE
        BEGIN
            PRINT N'Lỗi khác: ' + ERROR_MESSAGE();
            BREAK;  -- Thoát vòng lặp
        END
    END CATCH
END

IF @Success = 0
    PRINT N'Thất bại sau ' + CAST(@MaxRetries AS NVARCHAR(10)) + N' lần thử!';

GO

-- =============================================
-- PHẦN 4: VÍ DỤ THỰC TẾ - CẬP NHẬT STOCK AN TOÀN
-- =============================================

-- 4.1. Stored Procedure cập nhật Stock an toàn
IF OBJECT_ID('dbo.sp_UpdateStock_Safe', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_UpdateStock_Safe;
GO

CREATE PROCEDURE sp_UpdateStock_Safe
    @ProductId INT,
    @QuantityChange INT,  -- Số lượng thay đổi (âm = trừ, dương = cộng)
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Success = 0;
    SET @ErrorMessage = NULL;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
            DECLARE @CurrentStock INT;
            DECLARE @NewStock INT;
            
            -- Khóa dòng để đọc Stock
            SELECT @CurrentStock = Stock
            FROM dbo.Products WITH (UPDLOCK, HOLDLOCK)
            WHERE ProductId = @ProductId AND IsActive = 1;
            
            IF @CurrentStock IS NULL
            BEGIN
                SET @ErrorMessage = N'Sản phẩm không tồn tại hoặc không hoạt động';
                ROLLBACK TRANSACTION;
                RETURN;
            END
            
            SET @NewStock = @CurrentStock + @QuantityChange;
            
            -- Kiểm tra Stock không âm
            IF @NewStock < 0
            BEGIN
                SET @ErrorMessage = N'Không đủ hàng! Có: ' + CAST(@CurrentStock AS NVARCHAR(10)) + 
                                   N', Cần: ' + CAST(ABS(@QuantityChange) AS NVARCHAR(10));
                ROLLBACK TRANSACTION;
                RETURN;
            END
            
            -- Cập nhật Stock
            UPDATE dbo.Products
            SET Stock = @NewStock
            WHERE ProductId = @ProductId;
            
            SET @Success = 1;
            
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END
GO

-- Ví dụ sử dụng sp_UpdateStock_Safe
DECLARE @Success BIT;
DECLARE @ErrorMsg NVARCHAR(500);

-- Trừ 5 sản phẩm
EXEC sp_UpdateStock_Safe 
    @ProductId = 1, 
    @QuantityChange = -5,
    @Success = @Success OUTPUT,
    @ErrorMessage = @ErrorMsg OUTPUT;

IF @Success = 1
    PRINT N'Cập nhật Stock thành công!';
ELSE
    PRINT N'Lỗi: ' + @ErrorMsg;

GO

-- 4.2. Stored Procedure tạo đơn hàng với Transaction
IF OBJECT_ID('dbo.sp_CreateOrder_Simple', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CreateOrder_Simple;
GO

CREATE PROCEDURE sp_CreateOrder_Simple
    @UserId NVARCHAR(450),
    @ProductId INT,
    @Quantity INT,
    @ShippingAddress NVARCHAR(500),
    @OrderId INT OUTPUT,
    @Success BIT OUTPUT,
    @ErrorMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Success = 0;
    SET @OrderId = NULL;
    SET @ErrorMessage = NULL;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
            DECLARE @ProductPrice DECIMAL(18,2);
            DECLARE @CurrentStock INT;
            DECLARE @Total DECIMAL(18,2);
            
            -- Bước 1: Kiểm tra sản phẩm và stock
            SELECT @ProductPrice = Price, @CurrentStock = Stock
            FROM dbo.Products WITH (UPDLOCK, HOLDLOCK)
            WHERE ProductId = @ProductId AND IsActive = 1;
            
            IF @ProductPrice IS NULL
            BEGIN
                SET @ErrorMessage = N'Sản phẩm không tồn tại';
                ROLLBACK TRANSACTION;
                RETURN;
            END
            
            IF @CurrentStock < @Quantity
            BEGIN
                SET @ErrorMessage = N'Không đủ hàng! Có: ' + CAST(@CurrentStock AS NVARCHAR(10));
                ROLLBACK TRANSACTION;
                RETURN;
            END
            
            -- Bước 2: Tạo đơn hàng
            SET @Total = @ProductPrice * @Quantity;
            
            INSERT INTO dbo.Orders (
                UserId, OrderDate, Total, ShippingAddress,
                PaymentMethod, PaymentStatus, OrderStatus
            )
            VALUES (
                @UserId, GETUTCDATE(), @Total, @ShippingAddress,
                'COD', 'COD', 'Pending'
            );
            
            SET @OrderId = SCOPE_IDENTITY();
            
            -- Bước 3: Thêm chi tiết đơn hàng
            INSERT INTO dbo.OrderItems (OrderId, ProductId, Quantity, UnitPrice)
            VALUES (@OrderId, @ProductId, @Quantity, @ProductPrice);
            
            -- Bước 4: Trừ Stock
            UPDATE dbo.Products
            SET Stock = Stock - @Quantity
            WHERE ProductId = @ProductId;
            
            SET @Success = 1;
            
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH
END
GO

-- Ví dụ sử dụng sp_CreateOrder_Simple
DECLARE @NewOrderId INT;
DECLARE @Success BIT;
DECLARE @ErrorMsg NVARCHAR(500);
DECLARE @TestUserId NVARCHAR(450) = (SELECT TOP 1 Id FROM dbo.AspNetUsers);

EXEC sp_CreateOrder_Simple
    @UserId = @TestUserId,
    @ProductId = 1,
    @Quantity = 2,
    @ShippingAddress = N'123 Đường ABC, TP.HCM',
    @OrderId = @NewOrderId OUTPUT,
    @Success = @Success OUTPUT,
    @ErrorMessage = @ErrorMsg OUTPUT;

IF @Success = 1
    PRINT N'Tạo đơn hàng thành công! OrderId = ' + CAST(@NewOrderId AS NVARCHAR(10));
ELSE
    PRINT N'Lỗi: ' + @ErrorMsg;

GO

-- =============================================
-- PHẦN 5: TRANSACTION ISOLATION LEVEL
-- =============================================

/*
CÁC MỨC ĐỘ CÁCH LY (ISOLATION LEVEL):

1. READ UNCOMMITTED (Mức thấp nhất)
   - Cho phép đọc dữ liệu chưa commit (dirty read)
   - Nhanh nhưng không chính xác
   - Dùng cho: Dashboard, thống kê không quan trọng

2. READ COMMITTED (Mặc định)
   - Chỉ đọc dữ liệu đã commit
   - Cân bằng giữa hiệu năng và tính chính xác
   - Dùng cho: Hầu hết trường hợp

3. REPEATABLE READ
   - Đảm bảo đọc cùng dữ liệu nhiều lần trong transaction
   - Khóa các dòng đã đọc
   - Dùng cho: Tính toán cần độ chính xác cao

4. SERIALIZABLE (Mức cao nhất)
   - Cách ly hoàn toàn giữa các transaction
   - Chậm nhất nhưng an toàn nhất
   - Dùng cho: Giao dịch tài chính quan trọng
*/

-- Ví dụ thay đổi Isolation Level
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- Đọc nhanh, có thể đọc dữ liệu chưa commit
SELECT COUNT(*) FROM dbo.Orders;
GO

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- Quay về mức mặc định
GO

-- =============================================
-- TÓM TẮT CÁC KHÁI NIỆM QUAN TRỌNG
-- =============================================
PRINT '';
PRINT '=============================================';
PRINT 'TÓM TẮT TRANSACTION VÀ CONCURRENCY CONTROL';
PRINT '=============================================';
PRINT '';
PRINT '1. TRANSACTION (Giao dịch):';
PRINT '   - BEGIN TRANSACTION: Bắt đầu giao dịch';
PRINT '   - COMMIT: Lưu thay đổi';
PRINT '   - ROLLBACK: Hủy thay đổi';
PRINT '';
PRINT '2. LOCKING (Khóa):';
PRINT '   - UPDLOCK: Khóa để chuẩn bị update';
PRINT '   - HOLDLOCK: Giữ khóa đến hết transaction';
PRINT '   - NOLOCK: Đọc không cần chờ (dirty read)';
PRINT '';
PRINT '3. DEADLOCK (Bế tắc):';
PRINT '   - Xảy ra khi 2 transaction khóa chéo nhau';
PRINT '   - Tránh bằng cách khóa theo thứ tự nhất quán';
PRINT '   - Xử lý bằng TRY-CATCH và retry';
PRINT '';
PRINT '4. STORED PROCEDURES ĐÃ TẠO:';
PRINT '   - sp_UpdateStock_Safe: Cập nhật Stock an toàn';
PRINT '   - sp_CreateOrder_Simple: Tạo đơn hàng với transaction';
PRINT '';
PRINT 'LƯU Ý: Entity Framework đã tự động xử lý phần lớn';
PRINT '       các vấn đề concurrency trong C# code!';
PRINT '=============================================';
GO
