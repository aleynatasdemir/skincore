const { MongoClient } = require('mongodb');
async function run() {
  const client = new MongoClient('mongodb://localhost:27017');
  await client.connect();
  const db = client.db('kozmetik');
  const collection = db.collection('ProductsCollection');
  const product = await collection.findOne({ barcode: '8690644147234' });
  console.log('Embedding present:', !!product.embedding, 'Length:', product.embedding ? product.embedding.length : 0);
  client.close();
}
run().catch(console.dir);
