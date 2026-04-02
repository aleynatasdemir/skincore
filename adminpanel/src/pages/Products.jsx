import { useEffect, useMemo, useState } from 'react'
import Layout from '../components/Layout'
import { apiFetch } from '../api'

const STATUS_TABS = ['pending', 'reviewed', 'added']

const INITIAL_FORM = {
  barcode: '',
  brand: '',
  name: '',
  imageUrl: '',
  ingredientsText: '',
  ocrText: '',
}

function extractIngredientsFromOcr(text) {
  if (!text) return ''

  const lines = text
    .split('\n')
    .map(x => x.trim())
    .filter(Boolean)

  const line = lines.find(x => /^ingredients?[:\s]/i.test(x))
  if (line) return line.replace(/^ingredients?[:\s]*/i, '').trim()

  const idx = text.toLowerCase().indexOf('ingredients')
  if (idx === -1) return ''

  const tail = text.slice(idx).replace(/^ingredients?[:\s]*/i, '').trim()
  return tail.split('\n')[0]?.trim() || ''
}

function splitIngredients(text) {
  if (!text) return []
  return text.split(',').map(x => x.trim()).filter(Boolean)
}

function buildInsight(form, selectedRequest, ocrConfidence) {
  const ingredientsCount = splitIngredients(form.ingredientsText).length
  if (!selectedRequest) return 'Talep seçildiğinde moderasyon içgörüsü burada gösterilir.'
  if (ingredientsCount >= 5 && ocrConfidence && ocrConfidence >= 90) {
    return `OCR güveni yüksek (${ocrConfidence.toFixed(1)}%). İçerik listesi güçlü görünüyor, marka tutarlılığı kontrol edilip hızlı onay verilebilir.`
  }
  if (!form.ocrText) {
    return 'OCR henüz çalıştırılmadı. Görseldeki metni otomatik çekmek için OCR aksiyonunu kullanın.'
  }
  if (ingredientsCount === 0) {
    return 'OCR metni var ancak ingredient ayrıştırması boş. Kaydetmeden önce içerik alanını kontrol etmen önerilir.'
  }
  return `${ingredientsCount} ingredient algılandı. Onay öncesi ürün adı ve barkod doğrulaması yapman yeterli.`
}

export default function Products() {
  const [status, setStatus] = useState('pending')
  const [requests, setRequests] = useState([])
  const [selectedId, setSelectedId] = useState(null)
  const [loading, setLoading] = useState(false)
  const [form, setForm] = useState(INITIAL_FORM)
  const [sourceTab, setSourceTab] = useState('ingredients')
  const [selectionStartedAt, setSelectionStartedAt] = useState(Date.now())
  const [actionLoading, setActionLoading] = useState(false)
  const [actionMessage, setActionMessage] = useState('')
  const [ocr, setOcr] = useState({
    loading: false,
    error: '',
    confidence: null,
    characterCount: 0,
    lastRunAt: null,
  })

  const selectedRequest = useMemo(
    () => requests.find(r => r.id === selectedId) || null,
    [requests, selectedId]
  )

  const activeImageUrl = useMemo(() => {
    if (!selectedRequest) return ''
    if (sourceTab === 'front') return selectedRequest.frontImageUrl || selectedRequest.ingredientsImageUrl || ''
    return selectedRequest.ingredientsImageUrl || selectedRequest.frontImageUrl || ''
  }, [selectedRequest, sourceTab])

  const ingredients = useMemo(() => splitIngredients(form.ingredientsText), [form.ingredientsText])
  const insight = useMemo(() => buildInsight(form, selectedRequest, ocr.confidence), [form, selectedRequest, ocr.confidence])
  const elapsedSeconds = Math.max(1, Math.floor((Date.now() - selectionStartedAt) / 1000))

  useEffect(() => {
    loadRequests()
  }, [status])

  useEffect(() => {
    if (!selectedRequest) {
      setForm(INITIAL_FORM)
      return
    }

    setSelectionStartedAt(Date.now())
    setSourceTab(selectedRequest.ingredientsImageUrl ? 'ingredients' : 'front')
    setActionMessage('')
    setOcr({ loading: false, error: '', confidence: null, characterCount: 0, lastRunAt: null })
    setForm({
      barcode: '',
      brand: selectedRequest.brandName || '',
      name: selectedRequest.productName || '',
      imageUrl: selectedRequest.frontImageUrl || selectedRequest.ingredientsImageUrl || '',
      ingredientsText: '',
      ocrText: '',
    })
  }, [selectedRequest?.id])

  async function loadRequests() {
    setLoading(true)
    try {
      const res = await apiFetch(`/admin/product-requests?status=${status}&limit=50`)
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Talepler alınamadı.')

      const items = data.data || []
      setRequests(items)

      if (items.length === 0) {
        setSelectedId(null)
      } else if (!items.some(x => x.id === selectedId)) {
        setSelectedId(items[0].id)
      }
    } catch (err) {
      setRequests([])
      setSelectedId(null)
      setActionMessage(err.message)
    } finally {
      setLoading(false)
    }
  }

  async function runOcr() {
    if (!activeImageUrl) {
      setOcr(p => ({ ...p, error: 'OCR için geçerli bir görsel URL bulunamadı.' }))
      return
    }

    setOcr(p => ({ ...p, loading: true, error: '' }))
    try {
      const res = await apiFetch('/admin/ocr/extract', {
        method: 'POST',
        body: JSON.stringify({ imageUrl: activeImageUrl }),
      })

      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'OCR başarısız oldu.')

      const extractedText = data.text || ''
      const extractedIngredients = extractIngredientsFromOcr(extractedText)

      setForm(prev => ({
        ...prev,
        ocrText: extractedText,
        ingredientsText: prev.ingredientsText || extractedIngredients,
      }))

      setOcr({
        loading: false,
        error: '',
        confidence: data.confidence ?? null,
        characterCount: data.characterCount ?? extractedText.length,
        lastRunAt: Date.now(),
      })
    } catch (err) {
      setOcr(p => ({
        ...p,
        loading: false,
        error: err.message,
      }))
    }
  }

  async function approveRequest() {
    if (!selectedRequest) return
    if (!form.name.trim()) {
      setActionMessage('Ürün adı zorunlu.')
      return
    }

    setActionLoading(true)
    setActionMessage('')
    try {
      const res = await apiFetch(`/admin/product-requests/${selectedRequest.id}/approve`, {
        method: 'POST',
        body: JSON.stringify({
          name: form.name.trim(),
          barcode: form.barcode.trim() || null,
          brand: form.brand.trim() || null,
          imageUrl: form.imageUrl.trim() || null,
          ingredientsText: form.ingredientsText.trim() || null,
          ocrText: form.ocrText.trim() || null,
        }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Kaydetme işlemi başarısız.')

      setActionMessage(`✓ Veritabanına eklendi (Product ID: ${data.productId}).`)
      await loadRequests()
    } catch (err) {
      setActionMessage(`Hata: ${err.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  async function rejectRequest() {
    if (!selectedRequest) return
    if (!confirm('Bu talebi silip reddetmek istediğine emin misin?')) return

    setActionLoading(true)
    setActionMessage('')
    try {
      const res = await apiFetch(`/admin/product-requests/${selectedRequest.id}`, { method: 'DELETE' })
      const data = await res.json()
      if (!res.ok) throw new Error(data.message || 'Talep silinemedi.')
      setActionMessage('Talep reddedildi ve silindi.')
      await loadRequests()
    } catch (err) {
      setActionMessage(`Hata: ${err.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  return (
    <Layout>
      <div className="max-w-7xl mx-auto">
        <div className="mb-8 flex flex-col md:flex-row md:items-end justify-between gap-4">
          <div>
            <h1 className="font-headline text-4xl font-extrabold tracking-tight text-primary">Moderation Entry</h1>
            <p className="text-on-surface-variant font-medium mt-1">OCR extraction ile ürün bilgisini doğrula ve kataloğa ekle.</p>
          </div>
          <div className="flex gap-3">
            <button
              onClick={rejectRequest}
              disabled={!selectedRequest || actionLoading}
              className="flex items-center gap-2 px-6 py-2.5 border border-outline-variant text-on-surface font-semibold rounded-md hover:bg-surface-container-high transition-colors disabled:opacity-50"
            >
              <span className="material-symbols-outlined text-error">block</span>
              Reject
            </button>
            <button
              onClick={approveRequest}
              disabled={!selectedRequest || actionLoading}
              className="flex items-center gap-2 px-8 py-2.5 bg-gradient-to-r from-primary to-primary-container text-white font-semibold rounded-md shadow-lg shadow-primary/10 hover:scale-[1.02] active:scale-95 transition-all disabled:opacity-60"
            >
              <span className="material-symbols-outlined">save</span>
              {actionLoading ? 'Saving...' : 'Save to Database'}
            </button>
          </div>
        </div>

        <div className="mb-6 flex gap-2">
          {STATUS_TABS.map(s => (
            <button
              key={s}
              onClick={() => setStatus(s)}
              className={`px-4 py-2 rounded-md text-xs font-bold uppercase tracking-widest transition-colors ${
                status === s
                  ? 'bg-slate-900 text-white'
                  : 'bg-surface-container-low text-on-surface-variant hover:bg-surface-container-high'
              }`}
            >
              {s}
            </button>
          ))}
        </div>

        <div className="mb-8 bg-surface-container-lowest rounded-xl border border-outline-variant/15 p-4">
          {loading ? (
            <p className="text-sm text-on-surface-variant">Talepler yükleniyor...</p>
          ) : requests.length === 0 ? (
            <p className="text-sm text-on-surface-variant">Bu statüde talep bulunmuyor.</p>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3">
              {requests.map(r => (
                <button
                  key={r.id}
                  onClick={() => setSelectedId(r.id)}
                  className={`text-left p-3 rounded-lg border transition-all ${
                    selectedId === r.id
                      ? 'border-primary bg-primary/5'
                      : 'border-outline-variant/20 hover:border-outline-variant/50 bg-surface'
                  }`}
                >
                  <p className="font-semibold text-sm truncate">{r.productName || 'Unnamed Product'}</p>
                  <p className="text-xs text-on-surface-variant truncate">{r.brandName || 'Unknown Brand'}</p>
                  <p className="text-[10px] text-slate-400 mt-1">{new Date(r.createdAt).toLocaleString()}</p>
                </button>
              ))}
            </div>
          )}
        </div>

        {actionMessage && (
          <div className={`mb-6 px-4 py-3 rounded-lg text-sm ${actionMessage.startsWith('✓') ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
            {actionMessage}
          </div>
        )}

        {!selectedRequest ? (
          <div className="bg-surface-container-lowest rounded-xl border border-outline-variant/15 p-10 text-center text-on-surface-variant">
            Moderasyon için bir ürün talebi seç.
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-start">
            <div className="space-y-6 lg:sticky lg:top-24">
              <div className="bg-surface-container-lowest rounded-xl shadow-sm overflow-hidden">
                <div className="p-4 border-b border-surface-container flex items-center justify-between bg-surface-container-low/50">
                  <span className="text-xs font-bold uppercase tracking-widest text-on-surface-variant flex items-center gap-2">
                    <span className="material-symbols-outlined text-sm">photo_camera</span>
                    Source Image
                  </span>
                  <div className="flex gap-2">
                    <button
                      onClick={() => setSourceTab('front')}
                      className={`px-2 py-1 rounded text-[10px] font-bold uppercase ${
                        sourceTab === 'front' ? 'bg-slate-900 text-white' : 'bg-surface-container text-on-surface-variant'
                      }`}
                    >
                      Front
                    </button>
                    <button
                      onClick={() => setSourceTab('ingredients')}
                      className={`px-2 py-1 rounded text-[10px] font-bold uppercase ${
                        sourceTab === 'ingredients' ? 'bg-slate-900 text-white' : 'bg-surface-container text-on-surface-variant'
                      }`}
                    >
                      Ingredients
                    </button>
                  </div>
                </div>
                <div className="relative aspect-square md:aspect-[4/3] bg-slate-100 flex items-center justify-center p-8">
                  {activeImageUrl ? (
                    <img src={activeImageUrl} className="w-full h-full object-contain drop-shadow-2xl" alt="Product source" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-slate-400">
                      <span className="material-symbols-outlined text-4xl">image_not_supported</span>
                    </div>
                  )}
                </div>
              </div>

              <div className="bg-surface-container-lowest rounded-xl shadow-sm">
                <div className="p-4 border-b border-surface-container flex items-center justify-between">
                  <span className="text-xs font-bold uppercase tracking-widest text-on-surface-variant flex items-center gap-2">
                    <span className="material-symbols-outlined text-sm">segment</span>
                    Raw OCR Output
                  </span>
                  <button
                    onClick={runOcr}
                    disabled={ocr.loading || !activeImageUrl}
                    className="px-3 py-1.5 rounded-md text-[11px] font-bold bg-primary text-white hover:opacity-90 disabled:opacity-50"
                  >
                    {ocr.loading ? 'Running OCR...' : 'Run OCR'}
                  </button>
                </div>
                <div className="p-6">
                  {ocr.error && <p className="text-sm text-red-600 mb-3">{ocr.error}</p>}
                  <div className="bg-surface-container-low rounded-md p-4 font-mono text-xs leading-relaxed text-on-surface-variant max-h-56 overflow-y-auto whitespace-pre-wrap">
                    {form.ocrText || 'OCR çıktısı burada görünecek.'}
                  </div>
                  <div className="mt-3 flex items-center justify-between text-[11px] text-on-surface-variant">
                    <span>Chars: {ocr.characterCount || 0}</span>
                    <span>{ocr.confidence ? `Confidence: ${ocr.confidence.toFixed(1)}%` : 'Confidence: N/A'}</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-surface-container-lowest rounded-xl shadow-sm overflow-hidden">
              <div className="p-4 border-b border-surface-container bg-surface-container-low/50">
                <span className="text-xs font-bold uppercase tracking-widest text-on-surface-variant flex items-center gap-2">
                  <span className="material-symbols-outlined text-sm">edit_note</span>
                  Data Verification
                </span>
              </div>

              <div className="p-8 space-y-8">
                <div>
                  <h3 className="text-sm font-bold text-slate-400 uppercase tracking-widest mb-4">Core Identification</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-2">
                      <label className="text-xs font-bold text-on-surface-variant">BARCODE (EAN/UPC)</label>
                      <input
                        className="w-full bg-surface-container-low border-b border-outline-variant focus:border-primary focus:ring-0 text-sm font-medium p-2.5 transition-all"
                        value={form.barcode}
                        onChange={e => setForm(p => ({ ...p, barcode: e.target.value }))}
                        placeholder="501234567890"
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="text-xs font-bold text-on-surface-variant">BRAND NAME</label>
                      <input
                        className="w-full bg-surface-container-low border-b border-outline-variant focus:border-primary focus:ring-0 text-sm font-medium p-2.5 transition-all"
                        value={form.brand}
                        onChange={e => setForm(p => ({ ...p, brand: e.target.value }))}
                        placeholder="Brand"
                      />
                    </div>
                  </div>
                </div>

                <div className="space-y-6">
                  <div className="space-y-2">
                    <label className="text-xs font-bold text-on-surface-variant">PRODUCT NAME</label>
                    <input
                      className="w-full bg-surface-container-low border-b border-outline-variant focus:border-primary focus:ring-0 text-sm font-medium p-2.5 transition-all"
                      value={form.name}
                      onChange={e => setForm(p => ({ ...p, name: e.target.value }))}
                      placeholder="Product Name"
                    />
                  </div>

                  <div className="space-y-2">
                    <label className="text-xs font-bold text-on-surface-variant">INGREDIENTS LIST</label>
                    <textarea
                      rows={4}
                      className="w-full bg-surface-container-low border-b border-outline-variant focus:border-primary focus:ring-0 text-sm font-medium p-2.5 transition-all resize-none"
                      value={form.ingredientsText}
                      onChange={e => setForm(p => ({ ...p, ingredientsText: e.target.value }))}
                      placeholder="Aqua, Glycerin, ..."
                    />
                  </div>

                  <div className="space-y-2">
                    <label className="text-xs font-bold text-on-surface-variant">RAW OCR TEXT</label>
                    <textarea
                      rows={5}
                      className="w-full bg-surface-container-low border-b border-outline-variant focus:border-primary focus:ring-0 text-sm font-medium p-2.5 transition-all resize-none font-mono"
                      value={form.ocrText}
                      onChange={e => setForm(p => ({ ...p, ocrText: e.target.value }))}
                      placeholder="OCR output..."
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <label className="text-xs font-bold text-on-surface-variant">PRIMARY PHOTO URL</label>
                  <div className="flex gap-2">
                    <input
                      className="w-full bg-surface-container-low border-b border-outline-variant focus:border-primary focus:ring-0 text-sm font-medium p-2.5 transition-all"
                      value={form.imageUrl}
                      onChange={e => setForm(p => ({ ...p, imageUrl: e.target.value }))}
                      placeholder="https://..."
                    />
                    <a
                      href={form.imageUrl || '#'}
                      target="_blank"
                      rel="noreferrer"
                      className="bg-surface-container-high px-3 rounded-md hover:bg-surface-dim transition-colors flex items-center"
                    >
                      <span className="material-symbols-outlined">open_in_new</span>
                    </a>
                  </div>
                </div>

                <div className="pt-4 border-t border-surface-container">
                  <label className="text-xs font-bold text-on-surface-variant block mb-3">AI SUGGESTED CATEGORIES</label>
                  <div className="flex flex-wrap gap-2">
                    {[
                      form.brand ? 'Brand Matched' : null,
                      ingredients.length > 0 ? 'Ingredients Parsed' : null,
                      ocr.confidence && ocr.confidence >= 90 ? 'High OCR Confidence' : null,
                      selectedRequest?.status === 'pending' ? 'Needs Review' : 'Post Review',
                    ]
                      .filter(Boolean)
                      .map(tag => (
                        <span
                          key={tag}
                          className="px-3 py-1 bg-secondary-fixed text-on-secondary-fixed-variant text-[10px] font-extrabold rounded-sm uppercase tracking-wider"
                        >
                          {tag}
                        </span>
                      ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        <div className="mt-10 grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-surface-container-low p-6 rounded-lg">
            <span className="text-xs font-bold text-on-surface-variant uppercase tracking-widest">Entry Confidence</span>
            <div className="mt-2 flex items-baseline gap-2">
              <span className="text-3xl font-headline font-extrabold">
                {ocr.confidence ? `${ocr.confidence.toFixed(1)}%` : 'N/A'}
              </span>
              <span className="text-on-tertiary-container font-bold text-xs">{ocr.confidence && ocr.confidence >= 90 ? 'VERY HIGH' : 'REVIEW'}</span>
            </div>
          </div>
          <div className="bg-surface-container-low p-6 rounded-lg">
            <span className="text-xs font-bold text-on-surface-variant uppercase tracking-widest">Operator Speed</span>
            <div className="mt-2 flex items-baseline gap-2">
              <span className="text-3xl font-headline font-extrabold">{elapsedSeconds}s</span>
              <span className="text-on-primary-container font-bold text-xs">{selectedRequest ? 'ACTIVE TASK' : 'IDLE'}</span>
            </div>
          </div>
          <div className="md:col-span-2 bg-surface-container-low p-6 rounded-lg border-l-4 border-tertiary-fixed">
            <span className="text-xs font-bold text-on-surface-variant uppercase tracking-widest">AI Moderation Insight</span>
            <p className="mt-2 text-sm text-on-surface font-medium">{insight}</p>
          </div>
        </div>
      </div>
    </Layout>
  )
}

