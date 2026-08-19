// Lightweight static-page enhancements.
// The checklist is intentionally local to the browser and does not send data anywhere.
document.querySelectorAll('.checklist input').forEach((box, index) => {
  const key = `letsTradeComplianceCheck_${index}`;
  box.checked = localStorage.getItem(key) === 'true';
  box.addEventListener('change', () => localStorage.setItem(key, box.checked));
});