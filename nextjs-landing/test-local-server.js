const express = require('express');
const path = require('path');
const app = express();
const PORT = 3000;

// Serve static files from out directory
app.use(express.static(path.join(__dirname, 'out')));

// Rewrite /app/** to /app/index.html (for Flutter app)
app.get('/app/*', (req, res) => {
  res.sendFile(path.join(__dirname, 'out', 'app', 'index.html'));
});

// All other routes go to landing page
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'out', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
  console.log(`Landing page: http://localhost:${PORT}/`);
  console.log(`Flutter app: http://localhost:${PORT}/app`);
});

