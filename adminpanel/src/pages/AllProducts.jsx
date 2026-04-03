import { useState, useEffect, useMemo } from 'react'
import Layout from '../components/Layout'
import { apiFetch } from '../api'
import ProductEditModal from '../components/ProductEditModal'

export default function AllProducts() {
  const [selectedProduct, setSelectedProduct] = useState(null)
  const [products, setProducts] = useState([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [searchBarcode, setSearchBarcode] = useState('')
  const [searchName, setSearchName] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  
  const limit = 30

  const totalPages = useMemo(() => Math.ceil(total / limit), [total, limit])

  const fetchProducts = async (currentPage = 1, currentBarcode = searchBarcode, currentName = searchName) => {
    setLoading(true)
    setError('')
    try {
      const q = new URLSearchParams()
      if (currentBarcode.trim()) q.append('barcode', currentBarcode.trim())
      if (currentName.trim()) q.append('name', currentName.trim())
      q.append('page', currentPage)
      q.append('limit', limit)

      const res = await apiFetch(`/admin/allproducts?${q.toString()}`)
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Ürünler yüklenirken bir hata oluştu.')

      const rawProducts = Array.isArray(data) ? data : (data.data || [])
      setProducts(rawProducts)
      setTotal(data.total || 0)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchProducts(page)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page])

  const handleSearch = (e) => {
    if (e) e.preventDefault()
    if (page === 1) {
      fetchProducts(1, searchBarcode, searchName)
    } else {
      setPage(1)
    }
  }

  const handleClear = () => {
    setSearchBarcode('')
    setSearchName('')
    if (page === 1) {
      fetchProducts(1, '', '')
    } else {
      setPage(1)
    }
  }

  return (
    <Layout>
      <div className="bg-surface-container-lowest rounded-xl shadow-sm border border-outline-variant/15 p-6 mb-6">
        <div className="flex items-center justify-between mb-4">
          <h1 className="text-2xl font-bold font-headline uppercase tracking-wide flex items-center">
            All Products 
            <span className="text-sm font-normal text-on-surface-variant font-body normal-case ml-3 bg-surface-container px-3 py-1 rounded-full">{total} items total</span>
          </h1>
        </div>
        
        <form onSubmit={handleSearch} className="flex flex-col sm:flex-row gap-3">
          <div className="relative flex-1">
            <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[18px]">barcode</span>
            <input
              className="w-full bg-surface-container border border-outline-variant rounded-lg focus:border-primary focus:ring-1 focus:ring-primary text-sm pl-10 pr-3 py-3 transition-all"
              placeholder="Barcode (Exact match)"
              value={searchBarcode}
              onChange={e => setSearchBarcode(e.target.value)}
            />
          </div>
          <div className="relative flex-1">
            <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-[18px]">search</span>
            <input
              className="w-full bg-surface-container border border-outline-variant rounded-lg focus:border-primary focus:ring-1 focus:ring-primary text-sm pl-10 pr-3 py-3 transition-all"
              placeholder="Product Name (Fuzzy match)"
              value={searchName}
              onChange={e => setSearchName(e.target.value)}
            />
          </div>
          
          <button
            type="submit"
            disabled={loading}
            className="bg-primary text-white px-6 py-3 rounded-lg font-semibold text-sm hover:bg-primary/90 flex items-center justify-center gap-2 shrink-0 transition-colors shadow-sm"
          >
            Search
          </button>
          
          {(searchBarcode || searchName) && (
            <button
              type="button"
              disabled={loading}
              onClick={handleClear}
              className="bg-surface-container-high text-on-surface hover:bg-outline-variant/20 px-4 py-3 rounded-lg font-semibold text-sm flex items-center justify-center shrink-0 transition-colors"
            >
              Clear
            </button>
          )}
        </form>
      </div>

      {error && (
        <div className="bg-red-50 text-red-600 border border-red-200 p-4 rounded-xl mb-6 text-sm flex items-center gap-2 font-medium">
          <span className="material-symbols-outlined">error</span>
          {error}
        </div>
      )}

      {loading ? (
        <div className="flex flex-col justify-center items-center py-32 text-on-surface-variant">
          <span className="material-symbols-outlined animate-spin text-4xl mb-4 text-primary">progress_activity</span>
          <p className="text-sm font-medium tracking-wide">Yükleniyor...</p>
        </div>
      ) : products.length === 0 ? (
        <div className="bg-surface-container-lowest border border-outline-variant/20 py-24 text-center rounded-xl text-on-surface-variant shadow-sm flex flex-col items-center">
          <div className="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mb-4">
            <span className="material-symbols-outlined text-3xl text-slate-400">search_off</span>
          </div>
          <h3 className="text-base font-semibold text-slate-700 mb-1">Arama sonucu bulunamadı</h3>
          <p className="text-sm text-slate-500">Girdiğiniz kriterlere uygun ürün veritabanında mevcut değil.</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 gap-5">
          {products.map(doc => {
            const tempImage = doc.image_urls?.[0]?.fileUrl || doc.image_urls?.[0]?.fileName || (typeof doc.image_urls?.[0] === 'string' ? doc.image_urls[0] : '') || doc.image_urls?.find?.(i=>i.fileUrl)?.fileUrl || ''
            
            // Fix absolute URIs and blob images
            const imageUrl = tempImage.startsWith('http') ? tempImage : (tempImage ? `https://skincore.blob.core.windows.net/products/${tempImage}` : '')

            return (
                <div 
                  key={doc.id || doc._id} 
                  onClick={() => setSelectedProduct(doc)}
                  className="cursor-pointer bg-white rounded-xl shadow-sm border border-outline-variant/20 overflow-hidden flex flex-col group hover:shadow-md hover:border-outline-variant/40 hover:border-primary transition-all duration-300"
                >
                <div className="relative aspect-square bg-[#F8F9FA] flex items-center justify-center p-6 border-b border-slate-100">
                  {imageUrl ? (
                    <img 
                      src={imageUrl} 
                      alt={doc.name} 
                      className="max-w-full max-h-full object-contain mix-blend-multiply group-hover:scale-105 transition-transform duration-500 ease-out" 
                      loading="lazy"
                    />
                  ) : (
                    <div className="flex flex-col items-center text-slate-300">
                      <span className="material-symbols-outlined text-5xl mb-2 opacity-50">image_not_supported</span>
                      <span className="text-[10px] uppercase font-bold tracking-widest">No Image</span>
                    </div>
                  )}
                </div>
                
                <div className="p-4 flex flex-col flex-1">
                  <p className="text-[10px] text-slate-500 font-bold tracking-widest uppercase mb-1.5 line-clamp-1">{doc.brand || 'Unknown Brand'}</p>
                  <p className="text-sm font-bold text-slate-800 leading-snug mb-3 line-clamp-2" title={doc.name}>{doc.name}</p>
                  
                  <div className="mt-auto flex items-center justify-between pt-3 border-t border-slate-50">
                    <div className="flex items-center text-slate-400 gap-1.5" title="Barcode">
                      <span className="material-symbols-outlined text-[14px]">barcode</span>
                      <span className="text-[11px] font-mono font-medium">{doc.barcode || 'N/A'}</span>
                    </div>
                    
                    <span className="text-[10px] font-bold text-primary-dark bg-primary/10 px-2 py-1 rounded-md" title="Ingredients Count">
                      {Array.isArray(doc.product_ingredients) ? doc.product_ingredients.length : (doc.product_ingredients?.length || 0)} ing
                    </span>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Pagination */}
      {!loading && totalPages > 1 && products.length > 0 && (
        <div className="flex items-center justify-center gap-2 mt-12 mb-8">
          <button
            disabled={page === 1 || loading}
            onClick={() => setPage(p => p - 1)}
            className="w-10 h-10 rounded-lg flex items-center justify-center bg-white border border-slate-200 shadow-sm text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:shadow-none transition-all"
          >
            <span className="material-symbols-outlined text-[18px]">chevron_left</span>
          </button>
          
          <div className="flex gap-1.5">
            {[...Array(totalPages)].map((_, i) => {
              const pNum = i + 1;
              if (
                pNum === 1 || 
                pNum === totalPages || 
                (pNum >= page - 2 && pNum <= page + 2)
              ) {
                return (
                  <button
                    key={pNum}
                    onClick={() => setPage(pNum)}
                    className={`w-10 h-10 rounded-lg flex items-center justify-center text-sm font-bold transition-all shadow-sm ${
                      page === pNum
                        ? 'bg-primary border-primary text-white shadow-primary/20'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50 border'
                    }`}
                  >
                    {pNum}
                  </button>
                )
              } else if (
                (pNum === page - 3 && page > 4) || 
                (pNum === page + 3 && page < totalPages - 3)
              ) {
                return <span key={pNum} className="w-8 h-10 flex items-center justify-center text-slate-400 font-bold tracking-widest text-[10px]">...</span>
              }
              return null;
            })}
          </div>

          <button
            disabled={page === totalPages || loading}
            onClick={() => setPage(p => p + 1)}
            className="w-10 h-10 rounded-lg flex items-center justify-center bg-white border border-slate-200 shadow-sm text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:shadow-none transition-all"
          >
            <span className="material-symbols-outlined text-[18px]">chevron_right</span>
          </button>
        </div>
      )}

      {selectedProduct && (
        <ProductEditModal 
          product={selectedProduct} 
          onClose={() => setSelectedProduct(null)} 
          onSaved={() => {
             setSelectedProduct(null)
             fetchProducts(page)
          }} 
        />
      )}
    </Layout>
  )
}
