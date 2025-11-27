using Bookstore.Models;
using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Net;
using System.Web;
using System.Web.Mvc;

namespace Bookstore.Controllers
{
    public class ProductsController : Controller
    {
        private BookstoreDbEntities db = new BookstoreDbEntities();
        // GET: Products
        public ActionResult Index()
        {
            var products = db.Products
                .Include(p => p.Categories)
                .Where(p => p.IsActive)
                .ToList();
            return View(products);
        }

        // GET: Products/Details/:id
        public ActionResult Details(int? id)
        {
            if (id == null) return new HttpStatusCodeResult(HttpStatusCode.BadRequest);

            var product = db.Products
                .Include(p => p.Categories)
                .Include(p => p.ProductImages)
                .Include(p => p.Reviews)
                .FirstOrDefault(p => p.ProductId == id && p.IsActive);

            if (product == null) return HttpNotFound();
            return View(product);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                db.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}