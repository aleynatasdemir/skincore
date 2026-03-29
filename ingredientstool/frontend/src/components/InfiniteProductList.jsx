import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Loader, ImageIcon, CheckCircle } from 'lucide-react';

const API_BASE_URL = import.meta.env.VITE_API_URL || `http://${window.location.hostname}:5217`;

const InfiniteProductList = () => {
  const [products, setProducts] = useState([]);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [hasMore, setHasMore] = useState(true);
  
  // State to track text inputs independently for each product id
  const [draftContents, setDraftContents] = useState({});
  const [savingId, setSavingId] = useState(null);
  const [analyzingId, setAnalyzingId] = useState(null);

  const observer = useRef();

  const lastProductElementRef = useCallback((node) => {
    if (loading) return;
    if (observer.current) observer.current.disconnect();
    observer.current = new IntersectionObserver(entries => {
      if (entries[0].isIntersecting && hasMore) {
        setPage(prevPage => prevPage + 1);
      }
    });
    if (node) observer.current.observe(node);
  }, [loading, hasMore]);

  useEffect(() => {
    fetchProducts();
  }, [page]);

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const resp = await fetch(`${API_BASE_URL}/api/products/unprocessed-list?page=${page}&limit=10`);
      if (resp.ok) {
        const data = await resp.json();
        setProducts(prev => {
          // avoid duplicates just in case
          const existingIds = new Set(prev.map(p => p.id));
          const newProducts = data.filter(p => !existingIds.has(p.id));
          return [...prev, ...newProducts];
        });
        if (data.length === 0) setHasMore(false);
      }
    } catch (e) {
      console.error("Fetch products failed", e);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (id) => {
    setSavingId(id);
    try {
      const content = draftContents[id] || "";
      const resp = await fetch(`${API_BASE_URL}/api/products/${id}/draft`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content })
      });
      
      if (resp.ok) {
        // Immediately remove from list
        setProducts(prev => prev.filter(p => p.id !== id));
      } else {
        alert("Kaydetme başarısız oldu.");
      }
    } catch (error) {
      console.error(error);
      alert("Hata oluştu.");
    } finally {
      setSavingId(null);
    }
  };

  const handleSkip = async (id) => {
    setSavingId(id); // Using savingId to disable buttons while skipping
    try {
      const resp = await fetch(`${API_BASE_URL}/api/products/${id}/skip`, { method: 'POST' });
      if (resp.ok) {
        setProducts(prev => prev.filter(p => p.id !== id));
      }
    } catch (e) {
      console.error(e);
    } finally {
      setSavingId(null);
    }
  };

  const handleTextChange = (id, text) => {
    setDraftContents(prev => ({...prev, [id]: text}));
  };

  const handleImageUpload = async (event, productId, barcode) => {
    const file = event.target.files[0];
    if (!file) return;

    setAnalyzingId(productId);
    const formData = new FormData();
    formData.append('image', file);
    if (barcode) {
      formData.append('barcode', barcode);
    }

    try {
      const resp = await fetch(`${API_BASE_URL}/api/products/analyze-image`, {
        method: 'POST',
        body: formData
      });
      
      if (resp.ok) {
        const data = await resp.json();
        if (data.extractedContent) {
          setDraftContents(prev => ({...prev, [productId]: data.extractedContent}));
        } else {
          alert("Görselden hiçbir metin okunamadı.");
        }
      } else {
        const errorData = await resp.text();
        alert("Görsel analizi başarısız oldu: " + errorData);
      }
    } catch (error) {
      console.error('OCR Error:', error);
      alert("Hata: " + error.message);
    } finally {
      setAnalyzingId(null);
      event.target.value = null; // reset input
    }
  };

  if (products.length === 0 && !loading) {
    return (
      <main className="main-content" style={{ justifyContent: 'center' }}>
        <h2 className="page-title">İşlenecek Ürün Kalmadı</h2>
        <p className="page-subtitle">Tüm ürünler başarıyla tamamlandı.</p>
      </main>
    );
  }

  return (
    <main className="main-content" style={{ paddingBottom: '90px' }}>
      <div className="page-subtitle">SONSUZ LİSTE ("BATCH" MODU)</div>
      <h2 className="page-title">Toplu Ürün Girişi</h2>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem', width: '100%' }}>
        {products.map((product, index) => {
          const isLastElement = index === products.length - 1;
          const imageUrl = product.imageUrl;
          const isSaving = savingId === product.id;

          return (
            <div 
              key={product.id} 
              ref={isLastElement ? lastProductElementRef : null}
              className="entry-card" 
              style={{ display: 'flex', flexDirection: 'column', opacity: isSaving ? 0.5 : 1, pointerEvents: isSaving ? 'none' : 'auto' }}
            >
              <div style={{ display: 'flex', flexWrap: 'wrap' }}>
                <div className="image-upload-area" style={{ width: '250px', height: '250px', position: 'relative', flexShrink: 0 }}>
                  {imageUrl ? (
                    <img 
                      src={imageUrl} 
                      alt="Ürün" 
                      style={{ width: '100%', height: '100%', objectFit: 'contain' }}
                      onError={(e) => {
                        e.target.onerror = null; 
                        e.target.style.display = 'none';
                        e.target.nextSibling.style.display = 'flex';
                      }}
                    />
                  ) : null}
                  <div className="upload-icon-box" style={{ 
                    display: imageUrl ? 'none' : 'flex',
                    position: imageUrl ? 'absolute' : 'static',
                    top: '50%', left: '50%', transform: imageUrl ? 'translate(-50%, -50%)' : 'none'
                  }}>
                    <ImageIcon size={32} />
                  </div>
                </div>

                <div className="form-area" style={{ flex: 1, padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                  <div>
                    <label className="input-label">PRODUCT NAME</label>
                    <div style={{ fontWeight: '600', fontSize: '1.1rem', marginTop: '4px' }}>
                      {product.productName || product.name || '-'}
                    </div>
                  </div>
                  <div>
                    <label className="input-label">BARCODE</label>
                    <div style={{ color: '#666', marginTop: '4px' }}>
                      {product.barcode || '-'}
                    </div>
                  </div>
                  
                  <div style={{ display: 'flex', gap: '10px', marginTop: '0.5rem' }}>
                    
                    {/* OCR Upload Button */}
                    <input 
                      id={`camera-upload-${product.id}`}
                      type="file" 
                      accept="image/*" 
                      onChange={(e) => handleImageUpload(e, product.id, product.barcode)} 
                      style={{ display: 'none' }} 
                      disabled={analyzingId === product.id}
                    />
                    <label 
                      htmlFor={`camera-upload-${product.id}`} 
                      style={{ 
                        flexShrink: 0,
                        display: 'flex', 
                        alignItems: 'center', 
                        justifyContent: 'center', 
                        width: '80px', 
                        height: '80px', 
                        background: 'var(--accent-pink)', 
                        borderRadius: '8px', 
                        cursor: analyzingId === product.id ? 'not-allowed' : 'pointer',
                        opacity: analyzingId === product.id ? 0.7 : 1
                      }}
                    >
                      {analyzingId === product.id ? (
                        <Loader size={24} className="spin-icon" color="#8D6B71" />
                      ) : (
                        <div style={{ textAlign: 'center' }}>
                          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#8D6B71" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"></path><circle cx="12" cy="13" r="3"></circle></svg>
                          <div style={{ fontSize: '0.65rem', marginTop: '4px', color: '#8D6B71', fontWeight: 'bold' }}>TARA</div>
                        </div>
                      )}
                    </label>

                    {/* Text Field */}
                    <div style={{ flex: 1 }}>
                      <textarea 
                        style={{
                          width: '100%',
                          height: '80px',
                          padding: '0.75rem',
                          borderRadius: '8px',
                          border: '1px solid #ddd',
                          resize: 'vertical',
                          fontFamily: 'inherit'
                        }}
                        placeholder="Örn: Aqua, Glycerin..."
                        value={draftContents[product.id] || ''}
                        onChange={(e) => handleTextChange(product.id, e.target.value)}
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Action Bar for this specific product */}
              <div style={{ display: 'flex', borderTop: '1px solid #eee', background: '#fcfcfc' }}>
                <button 
                  onClick={() => handleSkip(product.id)}
                  style={{ flex: 1, padding: '1rem', color: '#666', fontWeight: '600', borderRight: '1px solid #eee' }}
                >
                  Atla
                </button>
                <button 
                  onClick={() => handleSave(product.id)}
                  style={{ flex: 2, padding: '1rem', background: 'var(--primary-color)', color: 'white', fontWeight: '600', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px' }}
                >
                  <CheckCircle size={18} /> Kaydet ve Geç
                </button>
              </div>
            </div>
          );
        })}

        {loading && (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '2rem' }}>
            <Loader size={32} className="spin-icon" color="#8D6B71" />
          </div>
        )}
      </div>
    </main>
  );
};

export default InfiniteProductList;
