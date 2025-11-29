using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Bookstore.ViewModels
{
    /// <summary>
    /// ViewModel for displaying a single cart item
    /// </summary>
    public class CartItemViewModel
    {
        public int CartItemId { get; set; }
        public int ProductId { get; set; }

        [Display(Name = "Tên sách")]
        public string ProductTitle { get; set; }

        [Display(Name = "Tác giả")]
        public string Author { get; set; }

        [Display(Name = "Đơn giá")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal UnitPrice { get; set; }

        [Display(Name = "Số lượng")]
        [Range(1, 100, ErrorMessage = "Số lượng phải từ 1 đến 100")]
        public int Quantity { get; set; }

        [Display(Name = "Thành tiền")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal Subtotal => UnitPrice * Quantity;

        [Display(Name = "Ảnh sản phẩm")]
        public string ImageUrl { get; set; }

        [Display(Name = "Tồn kho")]
        public int Stock { get; set; }

        [Display(Name = "Danh mục")]
        public string CategoryName { get; set; }

        [Display(Name = "Ngày thêm")]
        public DateTime DateAdded { get; set; }
    }

    /// <summary>
    /// ViewModel for the full cart view
    /// </summary>
    public class CartViewModel
    {
        public CartViewModel()
        {
            Items = new List<CartItemViewModel>();
        }

        public List<CartItemViewModel> Items { get; set; }

        [Display(Name = "Tổng số sản phẩm")]
        public int TotalItems => Items?.Count ?? 0;

        [Display(Name = "Tổng số lượng")]
        public int TotalQuantity { get; set; }

        [Display(Name = "Tổng tiền hàng")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal Subtotal { get; set; }

        [Display(Name = "Phí vận chuyển")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal ShippingFee { get; set; }

        [Display(Name = "Thuế VAT (10%)")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal Tax { get; set; }

        [Display(Name = "Tổng thanh toán")]
        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal Total => Subtotal + ShippingFee + Tax;

        public bool IsEmpty => Items == null || Items.Count == 0;
    }

    /// <summary>
    /// ViewModel for adding a product to cart
    /// </summary>
    public class AddToCartViewModel
    {
        [Required]
        public int ProductId { get; set; }

        [Range(1, 100, ErrorMessage = "Số lượng phải từ 1 đến 100")]
        public int Quantity { get; set; } = 1;
    }

    /// <summary>
    /// ViewModel for updating cart item quantity
    /// </summary>
    public class UpdateCartItemViewModel
    {
        [Required]
        public int CartItemId { get; set; }

        [Required]
        [Range(1, 100, ErrorMessage = "Số lượng phải từ 1 đến 100")]
        public int Quantity { get; set; }
    }

    /// <summary>
    /// ViewModel for mini cart display in navbar
    /// </summary>
    public class MiniCartViewModel
    {
        public int ItemCount { get; set; }

        [DisplayFormat(DataFormatString = "{0:N0}₫")]
        public decimal Total { get; set; }
    }

    /// <summary>
    /// Result model for cart operations returned as JSON
    /// </summary>
    public class CartOperationResult
    {
        public bool Success { get; set; }
        public string Message { get; set; }
        public int CartCount { get; set; }
        public decimal CartTotal { get; set; }
        public object Data { get; set; }
    }
}
