using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Bookstore.ViewModels
{
    #region Order List ViewModels

    /// <summary>
    /// ViewModel for displaying order summary in the order list
    /// Maps to results from sp_GetUserOrders stored procedure
    /// </summary>
    public class OrderSummaryViewModel
    {
        public int OrderId { get; set; }

        [Display(Name = "Mã đơn hàng")]
        public string OrderNumber { get; set; }

        [Display(Name = "Ngày đặt")]
        [DisplayFormat(DataFormatString = "{0:dd/MM/yyyy HH:mm}")]
        public DateTime OrderDate { get; set; }

        [Display(Name = "Tổng tiền")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal Total { get; set; }

        [Display(Name = "Trạng thái")]
        public string OrderStatus { get; set; }

        [Display(Name = "Phương thức thanh toán")]
        public string PaymentMethod { get; set; }

        [Display(Name = "Trạng thái thanh toán")]
        public string PaymentStatus { get; set; }

        [Display(Name = "Số sản phẩm")]
        public int ItemCount { get; set; }

        [Display(Name = "Ảnh sản phẩm")]
        public string FirstProductImage { get; set; }

        /// <summary>
        /// Get Bootstrap badge class based on order status
        /// </summary>
        public string StatusBadgeClass
        {
            get
            {
                switch (OrderStatus)
                {
                    case "Pending": return "badge bg-warning text-dark";
                    case "Processing": return "badge bg-info";
                    case "Shipped": return "badge bg-primary";
                    case "Delivered": return "badge bg-success";
                    case "Cancelled": return "badge bg-danger";
                    default: return "badge bg-secondary";
                }
            }
        }

        /// <summary>
        /// Get Vietnamese status display text
        /// </summary>
        public string StatusDisplayText
        {
            get
            {
                switch (OrderStatus)
                {
                    case "Pending": return "Chờ xử lý";
                    case "Processing": return "Đang xử lý";
                    case "Shipped": return "Đang giao";
                    case "Delivered": return "Đã giao";
                    case "Cancelled": return "Đã hủy";
                    default: return OrderStatus;
                }
            }
        }

        /// <summary>
        /// Get Vietnamese payment status display text
        /// </summary>
        public string PaymentStatusDisplayText
        {
            get
            {
                switch (PaymentStatus)
                {
                    case "Pending": return "Chờ thanh toán";
                    case "Paid": return "Đã thanh toán";
                    case "COD": return "Thanh toán khi nhận hàng";
                    case "Failed": return "Thanh toán thất bại";
                    case "Refunded": return "Đã hoàn tiền";
                    default: return PaymentStatus;
                }
            }
        }
    }

    /// <summary>
    /// ViewModel for orders list page with filtering and pagination
    /// </summary>
    public class OrderListViewModel
    {
        public OrderListViewModel()
        {
            Orders = new List<OrderSummaryViewModel>();
        }

        public List<OrderSummaryViewModel> Orders { get; set; }

        [Display(Name = "Lọc theo trạng thái")]
        public string CurrentStatus { get; set; }

        public int CurrentPage { get; set; }
        public int PageSize { get; set; }
        public int TotalOrders { get; set; }
        public int TotalPages => (int)Math.Ceiling((double)TotalOrders / PageSize);

        public bool HasPreviousPage => CurrentPage > 1;
        public bool HasNextPage => CurrentPage < TotalPages;
    }

    #endregion

    #region Order Details ViewModels

    /// <summary>
    /// ViewModel for order info (Result set 1 from sp_GetOrderDetails)
    /// </summary>
    public class OrderInfoViewModel
    {
        public int OrderId { get; set; }

        [Display(Name = "Mã đơn hàng")]
        public string OrderNumber { get; set; }

        [Display(Name = "Ngày đặt")]
        [DisplayFormat(DataFormatString = "{0:dd/MM/yyyy HH:mm}")]
        public DateTime OrderDate { get; set; }

        [Display(Name = "Tổng tiền")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal Total { get; set; }

        [Display(Name = "Trạng thái đơn hàng")]
        public string OrderStatus { get; set; }

        [Display(Name = "Phương thức thanh toán")]
        public string PaymentMethod { get; set; }

        [Display(Name = "Trạng thái thanh toán")]
        public string PaymentStatus { get; set; }

        [Display(Name = "Tên người nhận")]
        public string ShippingName { get; set; }

        [Display(Name = "Số điện thoại")]
        public string ShippingPhone { get; set; }

        [Display(Name = "Email")]
        public string ShippingEmail { get; set; }

        [Display(Name = "Địa chỉ giao hàng")]
        public string ShippingAddress { get; set; }

        [Display(Name = "Mã vận đơn")]
        public string TrackingNumber { get; set; }

        [Display(Name = "Ghi chú")]
        public string Notes { get; set; }

        [Display(Name = "Email khách hàng")]
        public string CustomerEmail { get; set; }

        [Display(Name = "Tên khách hàng")]
        public string CustomerName { get; set; }

        /// <summary>
        /// Get Bootstrap badge class based on order status
        /// </summary>
        public string StatusBadgeClass
        {
            get
            {
                switch (OrderStatus)
                {
                    case "Pending": return "badge bg-warning text-dark";
                    case "Processing": return "badge bg-info";
                    case "Shipped": return "badge bg-primary";
                    case "Delivered": return "badge bg-success";
                    case "Cancelled": return "badge bg-danger";
                    default: return "badge bg-secondary";
                }
            }
        }

        /// <summary>
        /// Get Vietnamese status display text
        /// </summary>
        public string StatusDisplayText
        {
            get
            {
                switch (OrderStatus)
                {
                    case "Pending": return "Chờ xử lý";
                    case "Processing": return "Đang xử lý";
                    case "Shipped": return "Đang giao";
                    case "Delivered": return "Đã giao";
                    case "Cancelled": return "Đã hủy";
                    default: return OrderStatus;
                }
            }
        }

        /// <summary>
        /// Get Vietnamese payment method display text
        /// </summary>
        public string PaymentMethodDisplayText
        {
            get
            {
                switch (PaymentMethod)
                {
                    case "COD": return "Thanh toán khi nhận hàng (COD)";
                    case "Stripe": return "Thẻ tín dụng/Ghi nợ (Stripe)";
                    case "BankTransfer": return "Chuyển khoản ngân hàng";
                    default: return PaymentMethod;
                }
            }
        }

        /// <summary>
        /// Get Vietnamese payment status display text
        /// </summary>
        public string PaymentStatusDisplayText
        {
            get
            {
                switch (PaymentStatus)
                {
                    case "Pending": return "Chờ thanh toán";
                    case "Paid": return "Đã thanh toán";
                    case "COD": return "Thanh toán khi nhận hàng";
                    case "Failed": return "Thanh toán thất bại";
                    case "Refunded": return "Đã hoàn tiền";
                    default: return PaymentStatus;
                }
            }
        }

        /// <summary>
        /// Check if the order can be cancelled
        /// </summary>
        public bool CanBeCancelled => OrderStatus == "Pending";
    }

    /// <summary>
    /// ViewModel for order item (Result set 2 from sp_GetOrderDetails)
    /// </summary>
    public class OrderItemViewModel
    {
        public int OrderItemId { get; set; }
        public int ProductId { get; set; }

        [Display(Name = "Số lượng")]
        public int Quantity { get; set; }

        [Display(Name = "Đơn giá")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal UnitPrice { get; set; }

        [Display(Name = "Tên sách")]
        public string ProductTitle { get; set; }

        [Display(Name = "Tác giả")]
        public string ProductAuthor { get; set; }

        [Display(Name = "Ảnh sản phẩm")]
        public string ProductImageUrl { get; set; }

        [Display(Name = "Thành tiền")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal Subtotal { get; set; }
    }

    /// <summary>
    /// ViewModel for payment history (Result set 3 from sp_GetOrderDetails)
    /// </summary>
    public class PaymentHistoryViewModel
    {
        public int PaymentId { get; set; }

        [Display(Name = "Phương thức")]
        public string PaymentMethod { get; set; }

        [Display(Name = "Trạng thái")]
        public string Status { get; set; }

        [Display(Name = "Ngày thanh toán")]
        [DisplayFormat(DataFormatString = "{0:dd/MM/yyyy HH:mm}")]
        public DateTime PaymentDate { get; set; }

        [Display(Name = "Số tiền")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal Amount { get; set; }

        [Display(Name = "Mã giao dịch")]
        public string TransactionId { get; set; }

        /// <summary>
        /// Get Bootstrap badge class based on payment status
        /// </summary>
        public string StatusBadgeClass
        {
            get
            {
                switch (Status)
                {
                    case "Pending": return "badge bg-warning text-dark";
                    case "Paid":
                    case "Completed": return "badge bg-success";
                    case "Failed": return "badge bg-danger";
                    case "Refunded": return "badge bg-info";
                    default: return "badge bg-secondary";
                }
            }
        }
    }

    /// <summary>
    /// Combined ViewModel for order details page
    /// Contains all 3 result sets from sp_GetOrderDetails
    /// </summary>
    public class OrderDetailsViewModel
    {
        public OrderDetailsViewModel()
        {
            Items = new List<OrderItemViewModel>();
            Payments = new List<PaymentHistoryViewModel>();
        }

        public OrderInfoViewModel Order { get; set; }
        public List<OrderItemViewModel> Items { get; set; }
        public List<PaymentHistoryViewModel> Payments { get; set; }
    }

    #endregion

    #region Checkout ViewModels

    /// <summary>
    /// ViewModel for checkout/place order form
    /// Maps to sp_CreateOrder parameters
    /// </summary>
    public class PlaceOrderViewModel
    {
        [Required(ErrorMessage = "Vui lòng nhập tên người nhận")]
        [StringLength(100, ErrorMessage = "Tên không được quá 100 ký tự")]
        [Display(Name = "Tên người nhận")]
        public string ShippingName { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập số điện thoại")]
        [Phone(ErrorMessage = "Số điện thoại không hợp lệ")]
        [StringLength(20, ErrorMessage = "Số điện thoại không được quá 20 ký tự")]
        [Display(Name = "Số điện thoại")]
        public string ShippingPhone { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập email")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ")]
        [StringLength(256, ErrorMessage = "Email không được quá 256 ký tự")]
        [Display(Name = "Email")]
        public string ShippingEmail { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập địa chỉ giao hàng")]
        [StringLength(500, ErrorMessage = "Địa chỉ không được quá 500 ký tự")]
        [Display(Name = "Địa chỉ giao hàng")]
        public string ShippingAddress { get; set; }

        [Required(ErrorMessage = "Vui lòng chọn phương thức thanh toán")]
        [Display(Name = "Phương thức thanh toán")]
        public string PaymentMethod { get; set; }

        [StringLength(1000, ErrorMessage = "Ghi chú không được quá 1000 ký tự")]
        [Display(Name = "Ghi chú")]
        public string Notes { get; set; }

        // Cart summary for display on checkout page
        public CartViewModel Cart { get; set; }
    }

    /// <summary>
    /// Result model for order operations
    /// </summary>
    public class OrderOperationResult
    {
        public bool Success { get; set; }
        public string Message { get; set; }
        public int? OrderId { get; set; }
        public string OrderNumber { get; set; }
    }

    #endregion
}
