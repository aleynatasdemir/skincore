import React, { useState } from 'react';
import { Search, LayoutList, Grip } from 'lucide-react';

const Header = ({ onSearch, viewMode, onToggleView }) => {
  const [query, setQuery] = useState('');

  const handleSearch = (e) => {
    e.preventDefault();
    if (query.trim()) {
      onSearch(query.trim());
    }
  };

  return (
    <header className="header" style={{ justifyContent: 'space-between', padding: '1rem 3rem' }}>
      <div className="logo-container" style={{ flex: 1 }}>
        <h1 className="logo-text" style={{ color: '#FF69B4', fontSize: '2rem', margin: 0 }}>skincore.</h1>
      </div>
      
      <form onSubmit={handleSearch} style={{ flex: 2, display: 'flex', justifyContent: 'center' }}>
        <div style={{ position: 'relative', width: '100%', maxWidth: '400px' }}>
          <input
            type="text"
            placeholder="Barkod veya Ürün İsmi arayın..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            style={{
              width: '100%',
              padding: '10px 40px 10px 20px',
              borderRadius: '20px',
              border: '1px solid #ddd',
              fontSize: '1rem',
              outline: 'none'
            }}
          />
          <button type="submit" style={{ position: 'absolute', right: '10px', top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer' }}>
            <Search size={20} color="#888" />
          </button>
        </div>
      </form>
      
      <div style={{ flex: 1, display: 'flex', justifyContent: 'flex-end', alignItems: 'center' }}>
        <button 
          onClick={onToggleView}
          style={{ 
            display: 'flex', 
            alignItems: 'center', 
            gap: '8px', 
            background: 'var(--primary-color)', 
            color: 'white', 
            padding: '8px 16px', 
            borderRadius: '20px', 
            fontWeight: '600' 
          }}
        >
          {viewMode === 'single' ? <LayoutList size={20} /> : <Grip size={20} />}
          {viewMode === 'single' ? 'Toplu Liste' : 'Tekli Mod'}
        </button>
      </div>
    </header>
  );
};

export default Header;
