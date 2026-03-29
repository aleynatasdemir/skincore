import React, { useState, useEffect } from 'react';
import { ImageIcon, Barcode, Camera, PenTool, Loader } from 'lucide-react';

const API_BASE_URL = import.meta.env.VITE_API_URL || `http://${window.location.hostname}:5217`;

const ProductEntry = ({ searchQuery, onSearchClear }) => {
  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showTextInput, setShowTextInput] = useState(false);
  const [textContent, setTextContent] = useState('');
  const [saving, setSaving] = useState(false);
  const [analyzing, setAnalyzing] = useState(false);

  useEffect(() => {
    fetchProduct(searchQuery);
  }, [searchQuery]);

  const fetchProduct = async (query = '') => {
    setLoading(true);
    setTextContent('');
    setShowTextInput(false);
    
    let url = `${API_BASE_URL}/api/products/next-unprocessed`;
    if (query) {
      url = `${API_BASE_URL}/api/products/search?q=${encodeURIComponent(query)}`;
    }

    try {
      const resp = await fetch(url);
      if (resp.ok) {
        let data = await resp.json();
        // If it was a search query, our backend returns an array. We take the first matched item.
        if (query && Array.isArray(data)) {
          if (data.length > 0) setProduct(data[0]);
          else setProduct(null);
        } else {
          setProduct(data);
        }
      } else {
        setProduct(null);
      }
    } catch (error) {
      console.error('Failed to fetch product:', error);
      setProduct(null);
    } finally {
      setLoading(false);
    }
  };

  const handleSaveDraft = async () => {
    if (!product) return;
    setSaving(true);
    
    try {
      const resp = await fetch(`${API_BASE_URL}/api/products/${product.id}/draft`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: textContent })
      });
      
      if (resp.ok) {
        alert("İçerik başarıyla kaydedildi!");
        setShowTextInput(false);
        setTextContent('');
        skipProduct(); // Auto skips
      } else {
        alert("Kaydetme başarısız oldu.");
      }
    } catch (error) {
      console.error(error);
      alert("Sunucuya bağlanılamadı.");
    } finally {
      setSaving(false);
    }
  };

  const handleImageUpload = async (event) => {
    const file = event.target.files[0];
    if (!file) return;

    setAnalyzing(true);
    const formData = new FormData();
    formData.append('image', file);
    if (product && product.barcode) {
      formData.append('barcode', product.barcode);
    }

    try {
      const resp = await fetch(`${API_BASE_URL}/api/products/analyze-image`, {
        method: 'POST',
        body: formData
      });
      
      if (resp.ok) {
        const data = await resp.json();
        if (data.extractedContent) {
          setTextContent(data.extractedContent);
        } else {
          alert("Görselden hiçbir metin okunamadı (boş sonuç döndü).");
        }
        setShowTextInput(true);
      } else {
        const errorData = await resp.text();
        alert("Görsel analizi başarısız oldu: " + errorData);
      }
    } catch (error) {
      console.error('OCR Error:', error);
      alert("Hata: Görsel analizi sırasında sunucuya ulaşılamadı. (" + error.message + ")");
    } finally {
      setAnalyzing(false);
      event.target.value = null; // reset input
    }
  };

  const skipProduct = async () => {
    if (searchQuery) {
      onSearchClear(); // Escape search mode
      return;
    } 

    if (product) {
      try {
        await fetch(`${API_BASE_URL}/api/products/${product.id}/skip`, { method: 'POST' });
      } catch (e) {
        console.error('Failed to skip product', e);
      }
    }
    fetchProduct(); // Fetch next unprocessed
  };

  if (loading) {
    return (
      <main className="main-content" style={{ justifyContent: 'center' }}>
        <Loader size={48} className="spin-icon" color="#8D6B71" />
        <p style={{ marginTop: '1rem', color: '#8D6B71' }}>Ürün yükleniyor...</p>
      </main>
    );
  }

  if (!product) {
    return (
      <main className="main-content" style={{ justifyContent: 'center' }}>
        <h2 className="page-title">{searchQuery ? 'Arama Sonucu Yok!' : 'İşlenecek Ürün Bulunamadı'}</h2>
        <p className="page-subtitle">
          {searchQuery 
            ? `"${searchQuery}" kuralıyla hiçbir barkod veya ürün bulunamadı.` 
            : 'Tüm ürünler işlenmiş veya veritabanı boş olabilir.'}
        </p>
        <button 
          className="btn-primary" 
          style={{ marginTop: '1rem', width: 'auto', padding: '10px 20px' }} 
          onClick={skipProduct}
        >
          {searchQuery ? 'Sıradaki Ürüne Dön' : 'Tekrar Kontrol Et'}
        </button>
      </main>
    );
  }

  const imageUrl = product.imageUrl ? product.imageUrl : null;

  return (
    <main className="main-content" style={{ paddingBottom: '90px' }}>
      <div className="page-subtitle">{searchQuery ? 'ARAMA SONUCU' : 'YENİ ÜRÜN GİRİŞİ'}</div>
      <h2 className="page-title">Product Entry</h2>

      <div className="entry-card">
        <div className="image-upload-area" style={{ position: 'relative' }}>
          {imageUrl ? (
            <img 
              src={imageUrl} 
              alt={product.productName || product.name || 'Ürün Görseli'} 
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
          <span className="upload-text" style={{ display: imageUrl ? 'none' : 'block' }}>Görsel Bulunamadı ({product.barcode})</span>
        </div>

        <div className="form-area">
          <div className="input-group">
            <label className="input-label">PRODUCT NAME</label>
            <div className="input-wrapper">
              <input 
                type="text" 
                className="input-field" 
                value={product.productName || product.name || ''} 
                readOnly
              />
            </div>
          </div>

          <div className="input-group">
            <label className="input-label">BARCODE</label>
            <div className="input-wrapper">
              <input 
                type="text" 
                className="input-field" 
                value={product.barcode || ''} 
                readOnly
              />
              <div className="barcode-icon">
                <Barcode size={24} strokeWidth={1.5} />
              </div>
            </div>
          </div>
        </div>

        <div className="action-buttons-container" style={{ padding: '0 2.5rem', display: 'flex', gap: '15px', marginBottom: '1.5rem' }}>
          {/* Hidden File Input */}
          <input 
            id="camera-upload"
            type="file" 
            accept="image/*" 
            onChange={handleImageUpload} 
            style={{ display: 'none' }} 
            disabled={analyzing}
          />

          <label htmlFor="camera-upload" className="action-card pink" style={{ flex: 1, cursor: analyzing ? 'not-allowed' : 'pointer', opacity: analyzing ? 0.7 : 1 }}>
            <div className="icon-circle">
              {analyzing ? (
                 <Loader size={20} className="spin-icon" color="#8D6B71" />
              ) : (
                 <Camera size={20} color="#8D6B71" />
              )}
            </div>
            <div>
              <div className="action-title">{analyzing ? 'Analiz Ediliyor...' : 'Fotoğraf ile İçerik Ekle'}</div>
              <div className="action-desc">Yapay zeka ile detayları tara</div>
            </div>
          </label>

          <button className="action-card gray" onClick={() => setShowTextInput(!showTextInput)} style={{ flex: 1 }}>
            <div className="icon-circle">
              <PenTool size={20} color="#4A4A4A" />
            </div>
            <div>
              <div className="action-title">Metin ile İçerik Ekle</div>
              <div className="action-desc">Manuel olarak içeriği girin</div>
            </div>
          </button>
        </div>
        
        {showTextInput && (
          <div style={{ padding: '0 2.5rem 2.5rem 2.5rem' }}>
            <label className="input-label" style={{ display: 'block', marginBottom: '0.5rem' }}>ÜRÜN İÇERİĞİ (METİN)</label>
            <textarea
              style={{
                width: '100%',
                minHeight: '120px',
                padding: '1rem',
                border: '2px solid var(--border-light)',
                borderRadius: '12px',
                fontFamily: 'inherit',
                fontSize: '1rem',
                resize: 'vertical',
                outline: 'none',
                marginBottom: '1rem'
              }}
              placeholder="İçerik metnini buraya yapıştırın. Virgüllerle ayırarak kaydedilecektir."
              value={textContent}
              onChange={(e) => setTextContent(e.target.value)}
              autoFocus
            />
          </div>
        )}

      </div>

      <div className="footer-info">
        İçerik eklendikten sonra ürün özelliklerini "Editorial Suite" üzerinden <br />
        düzenleyebilir ve yayınlanmaya hazır hale getirebilirsiniz.
      </div>
      
      {/* GLOBAL FOOTER ACTION BAR */}
      <div style={{
          position: 'fixed',
          bottom: 0,
          left: 0,
          right: 0,
          background: 'white',
          borderTop: '1px solid #ddd',
          padding: '1rem 2rem',
          display: 'flex',
          gap: '15px',
          zIndex: 1000,
          boxShadow: '0 -4px 12px rgba(0,0,0,0.06)'
        }}>
          <button className="btn-primary" onClick={handleSaveDraft} disabled={saving || !textContent.trim()} style={{ flex: 1, margin: 0, height: '54px', fontSize: '1.2rem' }}>
            {saving ? 'Kaydediliyor...' : 'Görüntülenen Ürünü (Taslağı) Kaydet'}
          </button>
          <button className="btn-secondary" onClick={skipProduct} style={{ 
            height: '54px', 
            padding: '0 40px', 
            borderRadius: '8px', 
            border: '1px solid #d1d5db', 
            background: '#f9fafb', 
            color: '#4b5563',
            fontWeight: '600',
            cursor: 'pointer',
            fontSize: '1.2rem' 
          }}>
            {searchQuery ? 'Geri Dön' : 'Atla'}
          </button>
      </div>

    </main>
  );
};

export default ProductEntry;
