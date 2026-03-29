import React, { useState } from 'react';
import Header from './components/Header';
import ProductEntry from './components/ProductEntry';
import InfiniteProductList from './components/InfiniteProductList';

function App() {
  const [searchQuery, setSearchQuery] = useState('');
  const [viewMode, setViewMode] = useState('single'); // 'single' veya 'list'

  return (
    <div className="app-container">
      <Header 
        onSearch={(q) => { setSearchQuery(q); setViewMode('single'); }} 
        viewMode={viewMode}
        onToggleView={() => setViewMode(prev => prev === 'single' ? 'list' : 'single')}
      />
      {viewMode === 'single' ? (
        <ProductEntry searchQuery={searchQuery} onSearchClear={() => setSearchQuery('')} />
      ) : (
        <InfiniteProductList />
      )}
    </div>
  );
}

export default App;
