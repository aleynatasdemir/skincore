import { useState, useEffect } from 'react'
import { apiFetch } from '../api'

export default function ProductEditModal({ product, onClose, onSaved }) {
 const [form, setForm] = useState({
 barcode: '',
 name: '',
 brand: '',
 product_ingredients: '',
 image_urls: ''
 })
 const [loading, setLoading] = useState(false)
 const [error, setError] = useState('')

 useEffect(() => {
 if (product) {
 setForm({
 barcode: product.barcode || '',
 name: product.name || '',
 brand: product.brand || '',
 product_ingredients: Array.isArray(product.product_ingredients) ? product.product_ingredients.join(', ') : '',
 image_urls: Array.isArray(product.image_urls) ? product.image_urls.map(i => i.fileUrl || i).filter(Boolean).join(', ') : ''
 })
 }
 }, [product])

 if (!product) return null

 const handleSubmit = async (e) => {
 if (e) e.preventDefault()
 setLoading(true)
 setError('')
 try {
 const body = {
 barcode: form.barcode,
 name: form.name,
 brand: form.brand,
 productIngredients: form.product_ingredients,
 imageUrls: form.image_urls
 }
 
 const res = await apiFetch(`/admin/products/${product.id || product._id}`, {
 method: 'PUT',
 body: JSON.stringify(body)
 })
 const data = await res.json()
 if (!res.ok) throw new Error(data.message || 'Güncelleme başarısız.')
 
 if (onSaved) onSaved()
 } catch(err) {
 setError(err.message)
 } finally {
 setLoading(false)
 }
 }

 const tempImage = product.image_urls?.[0]?.fileUrl || product.image_urls?.[0]?.fileName || (typeof product.image_urls?.[0] === 'string' ? product.image_urls[0] : '') || product.image_urls?.find?.(i=>i.fileUrl)?.fileUrl || ''
 const displayImageUrl = tempImage.startsWith('http') ? tempImage : (tempImage ? `https://skincore.blob.core.windows.net/products/${tempImage}` : '')

 return (
 <div className="fixed inset-0 z-50 flex items-center justify-center bg-surface-container-high/80 backdrop-blur-sm p-4 sm:p-8 overflow-y-auto w-full h-full" style={{fontFamily: 'Inter, sans-serif'}}>
 <div className="bg-surface-container-lowest rounded-2xl shadow-2xl w-full max-w-[1200px] flex flex-col max-h-[90vh] overflow-hidden border border-outline-variant/20 relative">
 
 {/* Close Button Top Right */}
 <button type="button" onClick={onClose} className="absolute right-6 top-6 z-20 p-2 hover:bg-surface-container-highest :bg-slate-800 rounded-full transition-colors group cursor-pointer">
 <span className="material-symbols-outlined text-on-surface-variant group-hover:text-on-surface text-[24px]">close</span>
 </button>

 <div className="flex-1 overflow-y-auto w-full h-full flex flex-col lg:flex-row">
 
 {/* Left: Product Image & Badges */}
 <div className="w-full lg:w-[45%] flex flex-col p-8 lg:p-12 bg-surface-container/30 border-r border-outline-variant/10 relative overflow-hidden">
 
 <div className="relative group w-full aspect-square bg-white border border-outline-variant/20 rounded-3xl flex items-center justify-center mb-8 shadow-sm">
 {displayImageUrl ? (
 <img className="w-full h-full object-contain mix-blend-multiply transition-transform duration-700 group-hover:scale-105 p-8" src={displayImageUrl} alt={product.name} />
 ) : (
 <div className="flex flex-col items-center justify-center text-outline-variant/50">
 <span className="material-symbols-outlined text-6xl mb-4 opacity-50">image_not_supported</span>
 <span className="text-xs uppercase font-bold tracking-widest text-center opacity-70">No Image<br/>Available</span>
 </div>
 )}

 {/* ID Badge */}
 <div className="absolute top-4 left-4 flex w-full pr-8">
 <div className="bg-black/80 backdrop-blur-md px-3 py-1.5 rounded-lg border border-white/20 transition-opacity flex items-center gap-2">
 <span className="material-symbols-outlined text-white text-[14px]">tag</span>
 <p className="text-[11px] font-mono text-white tracking-wider truncate max-w-[150px]">{product.id || product._id}</p>
 </div>
 </div>
 </div>
 
 {/* Status indicators */}
 <div className="flex flex-col gap-3 mt-auto">
 <div className="flex items-center justify-between bg-surface-container-lowest px-5 py-4 rounded-2xl border border-outline-variant/20 shadow-sm">
 <div className="flex items-center gap-3">
 <span className="material-symbols-outlined text-on-surface-variant ">database</span>
 <span className="text-[12px] font-bold text-on-surface-variant uppercase tracking-widest">Embedding Cache</span>
 </div>
 <div className="flex items-center gap-2">
 {product.has_embedding ? (
 <span className="px-3 py-1 bg-green-100 text-green-700 text-xs font-bold uppercase tracking-wider rounded-md border border-green-200 ">Active</span>
 ) : (
 <span className="px-3 py-1 bg-red-100 text-red-700 text-xs font-bold uppercase tracking-wider rounded-md border border-red-200 flex items-center gap-1.5"><span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse"></span>Missing</span>
 )}
 </div>
 </div>
 </div>
 </div>

 {/* Right: Editable Fields Form */}
 <div className="w-full lg:w-[55%] flex flex-col h-full bg-surface-container-lowest ">
 
 {/* Header section inside the form column */}
 <div className="px-8 lg:px-12 pt-10 pb-6 border-b border-surface-container-highest sticky top-0 bg-surface-container-lowest/90 backdrop-blur-md z-10">
 <div className="flex items-center gap-2 text-primary mb-2">
 <span className="material-symbols-outlined text-[18px]">edit_document</span>
 <span className="text-[11px] font-bold tracking-[0.2em] uppercase">Meta Data Editor</span>
 </div>
 <h2 className="text-2xl lg:text-3xl font-extrabold text-on-background tracking-tight" style={{fontFamily: 'Manrope, sans-serif'}}>
 Update Configuration
 </h2>
 {error && <div className="mt-4 p-3 bg-red-50 text-red-600 rounded-lg text-sm font-medium flex items-center gap-2 border border-red-100 "><span className="material-symbols-outlined text-[18px]">error</span> {error}</div>}
 </div>
 
 {/* Form scrollable area */}
 <div className="flex-1 overflow-y-auto px-8 lg:px-12 py-8">
 <form id="productEditForm" onSubmit={handleSubmit} className="flex flex-col gap-6">
 
 {/* Grid wrapper for basic info */}
 <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
 {/* Brand Name Field */}
 <div className="space-y-2">
 <label className="text-[12px] font-bold text-on-surface-variant flex items-center gap-2">
 <span className="material-symbols-outlined text-[16px]">storefront</span> Brand Name
 </label>
 <input type="text" value={form.brand} onChange={e => setForm({...form, brand: e.target.value})} className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-medium focus:bg-white :bg-slate-900 focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all placeholder:text-on-surface-variant/40" placeholder="Brand" />
 </div>

 {/* Barcode Field */}
 <div className="space-y-2">
 <label className="text-[12px] font-bold text-on-surface-variant flex items-center gap-2">
 <span className="material-symbols-outlined text-[16px]">barcode_scanner</span> Barcode (EAN/UPC)
 </label>
 <input type="text" value={form.barcode} onChange={e => setForm({...form, barcode: e.target.value})} className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-medium focus:bg-white :bg-slate-900 focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all font-mono text-sm" placeholder="0000000000000" />
 </div>
 </div>
 
 {/* Product Name Field */}
 <div className="space-y-2 pt-2">
 <label className="text-[12px] font-bold text-on-surface-variant flex items-center gap-2">
 <span className="material-symbols-outlined text-[16px]">inventory_2</span> Product Name
 </label>
 <input type="text" value={form.name} onChange={e => setForm({...form, name: e.target.value})} className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-medium focus:bg-white :bg-slate-900 focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all" placeholder="Enter full product name..." />
 </div>
 
 {/* Ingredients List */}
 <div className="space-y-2 pt-2">
 <label className="text-[12px] font-bold text-on-surface-variant flex items-center justify-between">
 <div className="flex items-center gap-2">
 <span className="material-symbols-outlined text-[16px]">science</span> Formula & Ingredients
 </div>
 <span className="text-[10px] font-mono bg-surface-container px-2 py-0.5 rounded text-on-surface-variant opacity-70">Comma separated</span>
 </label>
 <textarea rows="6" value={form.product_ingredients} onChange={e => setForm({...form, product_ingredients: e.target.value})} className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-mono text-[13px] leading-relaxed focus:bg-white :bg-slate-900 focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all resize-y" placeholder="AQUA, GLYCERIN, ..."></textarea>
 </div>
 
 {/* Master Image URLs */}
 <div className="space-y-2 pt-2 pb-4">
 <label className="text-[12px] font-bold text-on-surface-variant flex items-center gap-2">
 <span className="material-symbols-outlined text-[16px]">link</span> Source Image URLs
 </label>
 <div className="relative">
 <textarea rows="3" value={form.image_urls} onChange={e => setForm({...form, image_urls: e.target.value})} className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-mono text-[13px] focus:bg-white :bg-slate-900 focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all resize-y" placeholder="https://..., https://..."></textarea>
 </div>
 </div>
 </form>
 </div>

 {/* Footer Actions Fixed at Bottom */}
 <div className="px-8 lg:px-12 py-5 border-t border-surface-container-highest flex items-center justify-between bg-surface-container-lowest/95 mt-auto">
 <button type="button" onClick={onClose} className="px-5 py-2.5 text-on-surface-variant font-bold hover:text-on-surface :text-slate-200 transition-colors cursor-pointer text-sm">
 Discard Changes
 </button>
 <button form="productEditForm" type="submit" disabled={loading} className="px-8 py-3 bg-black text-white rounded-full font-bold flex items-center gap-2 hover:bg-slate-800 :bg-slate-100 transition-all shadow-lg active:scale-95 disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer text-sm">
 {loading ? (
 <span className="material-symbols-outlined animate-spin text-[18px]">progress_activity</span>
 ) : (
 <span className="material-symbols-outlined text-[18px]">save</span>
 )}
 Commit Update
 </button>
 </div>
 
 </div>
 </div>

 </div>
 </div>
 )
}
