import { useState, useEffect, useRef } from 'react'
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
  const [ocrState, setOcrState] = useState({ loading: false, message: '' })
  const [embedState, setEmbedState] = useState({ loading: false, message: '' })
  const [photoState, setPhotoState] = useState({ open: false, stream: null })
  const videoRef = useRef(null)
  const canvasRef = useRef(null)

  useEffect(() => {
    if (product) {
      setForm({
        barcode: product.barcode || '',
        name: product.name || '',
        brand: product.brand || '',
        product_ingredients: Array.isArray(product.product_ingredients) ? product.product_ingredients.join(', ') : '',
        image_urls: Array.isArray(product.image_urls) ? product.image_urls.map(i => i.fileUrl || i).filter(Boolean).join(', ') : ''
      })
      setOcrState({ loading: false, message: '' })
      setEmbedState({ loading: false, message: '' })
    }
  }, [product])

  if (!product) return null

  const primaryImageUrl = form.image_urls.split(',')[0]?.trim() || ''

  // ── Barkoddan fotoğraf çek ──
  async function lookupImageByBarcode() {
    const barcode = form.barcode.trim()
    if (!barcode) return
    try {
      const res = await apiFetch(`/admin/products/image-by-barcode?barcode=${encodeURIComponent(barcode)}`)
      const data = await res.json()
      if (!res.ok) throw new Error(data.message)
      if (data.imageUrl) setForm(p => ({ ...p, image_urls: data.imageUrl }))
    } catch (err) {
      setError(err.message)
    }
  }

  // ── Kamera ──
  async function openCamera() {
    setPhotoState({ open: true, stream: null })
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } })
      setPhotoState({ open: true, stream })
      if (videoRef.current) { videoRef.current.srcObject = stream; videoRef.current.play() }
    } catch {
      setPhotoState({ open: false, stream: null })
    }
  }

  function capturePhoto() {
    if (!videoRef.current || !canvasRef.current) return
    const v = videoRef.current; const c = canvasRef.current
    c.width = v.videoWidth; c.height = v.videoHeight
    c.getContext('2d').drawImage(v, 0, 0)
    const dataUrl = c.toDataURL('image/jpeg', 0.85)
    photoState.stream?.getTracks().forEach(t => t.stop())
    setPhotoState({ open: false, stream: null })
    setForm(p => ({ ...p, image_urls: dataUrl }))
  }

  function cancelCamera() {
    photoState.stream?.getTracks().forEach(t => t.stop())
    setPhotoState({ open: false, stream: null })
  }

  // ── OCR ──
  async function runOcr() {
    if (!primaryImageUrl) { setOcrState({ loading: false, message: 'Önce fotoğraf URL\'si girin.' }); return }
    setOcrState({ loading: true, message: '' })
    try {
      const body = primaryImageUrl.startsWith('data:')
        ? { imageBase64: primaryImageUrl }
        : { imageUrl: primaryImageUrl }
      const res = await apiFetch('/admin/ocr/extract', { method: 'POST', body: JSON.stringify(body) })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'OCR başarısız.')
      // ingredients satırını bul
      const text = data.text || ''
      const line = text.split('\n').find(l => /^ingredients?[:\s]/i.test(l.trim()))
      const extracted = line
        ? line.replace(/^ingredients?[:\s]*/i, '').trim()
        : text.split('\n')[0]?.trim() || ''
      if (extracted) setForm(p => ({ ...p, product_ingredients: p.product_ingredients || extracted }))
      setOcrState({ loading: false, message: `✓ OCR tamamlandı (${data.characterCount || text.length} karakter).` })
    } catch (err) {
      setOcrState({ loading: false, message: `Hata: ${err.message}` })
    }
  }

  // ── Embed ──
  async function embedProduct() {
    if (!primaryImageUrl) { setEmbedState({ loading: false, message: 'Önce fotoğraf URL\'si girin.' }); return }
    const barcode = form.barcode.trim() || null
    setEmbedState({ loading: true, message: '' })
    try {
      const body = primaryImageUrl.startsWith('data:')
        ? { imageBase64: primaryImageUrl.split(',')[1], barcode }
        : { imageUrl: primaryImageUrl, barcode }
      const res = await apiFetch('/admin/products/embed', { method: 'POST', body: JSON.stringify(body) })
      const text = await res.text()
      const data = text ? JSON.parse(text) : {}
      if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`)
      setEmbedState({ loading: false, message: `✓ Embedding kaydedildi (${data.dimensions} boyut).` })
    } catch (err) {
      setEmbedState({ loading: false, message: `Hata: ${err.message}` })
    }
  }

  // ── Save ──
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
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const displayImageUrl = primaryImageUrl || ''

  return (
    <>
      {/* Kamera Modal */}
      {photoState.open && (
        <div className="fixed inset-0 z-[60] bg-black/90 flex flex-col items-center justify-center gap-4 p-4">
          <p className="text-white text-sm font-bold uppercase tracking-widest">Fotoğraf Çek</p>
          <video ref={videoRef} autoPlay playsInline className="rounded-xl max-w-sm w-full" />
          <canvas ref={canvasRef} className="hidden" />
          <div className="flex gap-3">
            <button onClick={capturePhoto} className="px-6 py-2.5 bg-primary text-white font-bold rounded-md flex items-center gap-2">
              <span className="material-symbols-outlined">camera</span>Çek
            </button>
            <button onClick={cancelCamera} className="px-6 py-2.5 bg-white text-slate-800 font-bold rounded-md">İptal</button>
          </div>
        </div>
      )}

      <div className="fixed inset-0 z-50 flex items-center justify-center bg-surface-container-high/80 backdrop-blur-sm p-4 sm:p-8 overflow-y-auto w-full h-full" style={{ fontFamily: 'Inter, sans-serif' }}>
        <div className="bg-surface-container-lowest rounded-2xl shadow-2xl w-full max-w-[1200px] flex flex-col max-h-[90vh] overflow-hidden border border-outline-variant/20 relative">

          <button type="button" onClick={onClose} className="absolute right-6 top-6 z-20 p-2 hover:bg-surface-container-highest rounded-full transition-colors group cursor-pointer">
            <span className="material-symbols-outlined text-on-surface-variant group-hover:text-on-surface text-[24px]">close</span>
          </button>

          <div className="flex-1 overflow-y-auto w-full h-full flex flex-col lg:flex-row">

            {/* Sol: Görsel */}
            <div className="w-full lg:w-[45%] flex flex-col p-8 lg:p-12 bg-surface-container/30 border-r border-outline-variant/10 relative overflow-hidden">
              <div className="relative group w-full aspect-square bg-white border border-outline-variant/20 rounded-3xl flex items-center justify-center mb-6 shadow-sm">
                {displayImageUrl && !displayImageUrl.startsWith('data:') ? (
                  <img className="w-full h-full object-contain mix-blend-multiply transition-transform duration-700 group-hover:scale-105 p-8" src={displayImageUrl} alt={product.name} />
                ) : displayImageUrl.startsWith('data:') ? (
                  <img className="w-full h-full object-contain p-4" src={displayImageUrl} alt="captured" />
                ) : (
                  <div className="flex flex-col items-center justify-center text-outline-variant/50">
                    <span className="material-symbols-outlined text-6xl mb-4 opacity-50">image_not_supported</span>
                    <span className="text-xs uppercase font-bold tracking-widest text-center opacity-70">No Image</span>
                  </div>
                )}
                <div className="absolute top-4 left-4 flex w-full pr-8">
                  <div className="bg-black/80 backdrop-blur-md px-3 py-1.5 rounded-lg border border-white/20 flex items-center gap-2">
                    <span className="material-symbols-outlined text-white text-[14px]">tag</span>
                    <p className="text-[11px] font-mono text-white tracking-wider truncate max-w-[150px]">{product.id || product._id}</p>
                  </div>
                </div>
              </div>

              {/* OCR & Embed aksiyonları */}
              <div className="flex flex-col gap-3">
                {/* OCR */}
                <div className="flex flex-col gap-1.5">
                  <button
                    type="button"
                    onClick={runOcr}
                    disabled={ocrState.loading || !primaryImageUrl}
                    className="flex items-center justify-center gap-2 px-4 py-2.5 bg-slate-900 text-white rounded-xl font-bold text-sm hover:bg-slate-700 transition-colors disabled:opacity-50"
                  >
                    <span className="material-symbols-outlined text-[18px]">document_scanner</span>
                    {ocrState.loading ? 'Running OCR...' : 'Run OCR → Fill Ingredients'}
                  </button>
                  {ocrState.message && (
                    <p className={`text-xs px-1 ${ocrState.message.startsWith('✓') ? 'text-green-600' : 'text-red-500'}`}>{ocrState.message}</p>
                  )}
                </div>

                {/* Embed */}
                <div className="flex flex-col gap-1.5">
                  <button
                    type="button"
                    onClick={embedProduct}
                    disabled={embedState.loading || !primaryImageUrl}
                    className="flex items-center justify-center gap-2 px-4 py-2.5 bg-primary/10 text-primary rounded-xl font-bold text-sm hover:bg-primary/20 transition-colors disabled:opacity-50 border border-primary/20"
                  >
                    <span className="material-symbols-outlined text-[18px]">model_training</span>
                    {embedState.loading ? 'Embedding...' : 'Embed → Save Vector'}
                  </button>
                  {embedState.message && (
                    <p className={`text-xs px-1 ${embedState.message.startsWith('✓') ? 'text-green-600' : 'text-red-500'}`}>{embedState.message}</p>
                  )}
                </div>

                {/* Embedding durumu */}
                <div className="flex items-center justify-between bg-surface-container-lowest px-5 py-4 rounded-2xl border border-outline-variant/20 shadow-sm mt-1">
                  <div className="flex items-center gap-3">
                    <span className="material-symbols-outlined text-on-surface-variant">database</span>
                    <span className="text-[12px] font-bold text-on-surface-variant uppercase tracking-widest">Embedding Cache</span>
                  </div>
                  <div className="flex items-center gap-2">
                    {product.has_embedding || embedState.message.startsWith('✓') ? (
                      <span className="px-3 py-1 bg-green-100 text-green-700 text-xs font-bold uppercase tracking-wider rounded-md border border-green-200">Active</span>
                    ) : (
                      <span className="px-3 py-1 bg-red-100 text-red-700 text-xs font-bold uppercase tracking-wider rounded-md border border-red-200 flex items-center gap-1.5">
                        <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse"></span>Missing
                      </span>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Sağ: Form */}
            <div className="w-full lg:w-[55%] flex flex-col h-full bg-surface-container-lowest">

              <div className="px-8 lg:px-12 pt-10 pb-6 border-b border-surface-container-highest sticky top-0 bg-surface-container-lowest/90 backdrop-blur-md z-10">
                <div className="flex items-center gap-2 text-primary mb-2">
                  <span className="material-symbols-outlined text-[18px]">edit_document</span>
                  <span className="text-[11px] font-bold tracking-[0.2em] uppercase">Meta Data Editor</span>
                </div>
                <h2 className="text-2xl lg:text-3xl font-extrabold text-on-background tracking-tight" style={{ fontFamily: 'Manrope, sans-serif' }}>
                  Update Configuration
                </h2>
                {error && (
                  <div className="mt-4 p-3 bg-red-50 text-red-600 rounded-lg text-sm font-medium flex items-center gap-2 border border-red-100">
                    <span className="material-symbols-outlined text-[18px]">error</span> {error}
                  </div>
                )}
              </div>

              <div className="flex-1 overflow-y-auto px-8 lg:px-12 py-8">
                <form id="productEditForm" onSubmit={handleSubmit} className="flex flex-col gap-6">

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {/* Brand */}
                    <div className="space-y-2">
                      <label className="text-[12px] font-bold text-on-surface-variant flex items-center gap-2">
                        <span className="material-symbols-outlined text-[16px]">storefront</span> Brand Name
                      </label>
                      <input type="text" value={form.brand} onChange={e => setForm({ ...form, brand: e.target.value })}
                        className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-medium focus:bg-white focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all placeholder:text-on-surface-variant/40"
                        placeholder="Brand" />
                    </div>

                    {/* Barcode + butonlar */}
                    <div className="space-y-2">
                      <label className="text-[12px] font-bold text-on-surface-variant flex items-center gap-2">
                        <span className="material-symbols-outlined text-[16px]">barcode_scanner</span> Barcode (EAN/UPC)
                      </label>
                      <div className="flex gap-2">
                        <input type="text" value={form.barcode} onChange={e => setForm({ ...form, barcode: e.target.value })}
                          className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-medium focus:bg-white focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all font-mono text-sm"
                          placeholder="0000000000000" />
                        <button type="button" onClick={lookupImageByBarcode} title="Barkoddan fotoğraf çek"
                          className="shrink-0 bg-surface-container-high px-3 rounded-xl hover:bg-surface-dim transition-colors flex items-center border border-outline-variant/30">
                          <span className="material-symbols-outlined text-[18px]">image_search</span>
                        </button>
                        <button type="button" onClick={openCamera} title="Kamerayla fotoğraf çek"
                          className="shrink-0 bg-surface-container-high px-3 rounded-xl hover:bg-surface-dim transition-colors flex items-center border border-outline-variant/30">
                          <span className="material-symbols-outlined text-[18px]">photo_camera</span>
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Product Name */}
                  <div className="space-y-2">
                    <label className="text-[12px] font-bold text-on-surface-variant flex items-center gap-2">
                      <span className="material-symbols-outlined text-[16px]">inventory_2</span> Product Name
                    </label>
                    <input type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })}
                      className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-medium focus:bg-white focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all"
                      placeholder="Enter full product name..." />
                  </div>

                  {/* Ingredients */}
                  <div className="space-y-2">
                    <label className="text-[12px] font-bold text-on-surface-variant flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="material-symbols-outlined text-[16px]">science</span> Formula & Ingredients
                      </div>
                      <span className="text-[10px] font-mono bg-surface-container px-2 py-0.5 rounded text-on-surface-variant opacity-70">Comma separated</span>
                    </label>
                    <textarea rows="6" value={form.product_ingredients} onChange={e => setForm({ ...form, product_ingredients: e.target.value })}
                      className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-mono text-[13px] leading-relaxed focus:bg-white focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all resize-y"
                      placeholder="AQUA, GLYCERIN, ..."></textarea>
                  </div>

                  {/* Image URLs */}
                  <div className="space-y-2 pb-4">
                    <label className="text-[12px] font-bold text-on-surface-variant flex items-center gap-2">
                      <span className="material-symbols-outlined text-[16px]">link</span> Source Image URLs
                    </label>
                    <textarea rows="3" value={form.image_urls} onChange={e => setForm({ ...form, image_urls: e.target.value })}
                      className="w-full bg-surface-container/30 border border-outline-variant/30 rounded-xl px-4 py-3 text-on-surface font-mono text-[13px] focus:bg-white focus:ring-2 focus:ring-primary/20 focus:border-primary focus:outline-none transition-all resize-y"
                      placeholder="https://..., https://..."></textarea>
                  </div>
                </form>
              </div>

              {/* Footer */}
              <div className="px-8 lg:px-12 py-5 border-t border-surface-container-highest flex items-center justify-between bg-surface-container-lowest/95 mt-auto">
                <button type="button" onClick={onClose} className="px-5 py-2.5 text-on-surface-variant font-bold hover:text-on-surface transition-colors cursor-pointer text-sm">
                  Discard Changes
                </button>
                <button form="productEditForm" type="submit" disabled={loading}
                  className="px-8 py-3 bg-black text-white rounded-full font-bold flex items-center gap-2 hover:bg-slate-800 transition-all shadow-lg active:scale-95 disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer text-sm">
                  {loading ? <span className="material-symbols-outlined animate-spin text-[18px]">progress_activity</span> : <span className="material-symbols-outlined text-[18px]">save</span>}
                  Commit Update
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}
