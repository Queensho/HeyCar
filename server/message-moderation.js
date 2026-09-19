function normalizeText(value) {
  return String(value || '')
    .toLocaleLowerCase('tr-TR')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ı/g, 'i')
    .replace(/0/g, 'o')
    .replace(/[1!]/g, 'i')
    .replace(/3/g, 'e')
    .replace(/4/g, 'a')
    .replace(/5/g, 's')
    .replace(/7/g, 't')
    .replace(/@/g, 'a')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/(.)\1{2,}/g, '$1$1')
    .trim();
}

const blockedPatterns = [
  /(?:^|\s)(?:amk|aq|mk)(?:\s|$)/,
  /(?:^|\s)a\s+m\s+k(?:\s|$)/,
  /(?:^|\s)(?:orospu|orospu\s+cocugu|oc)(?:\s|$)/,
  /(?:^|\s)(?:pic)(?:\s|$)/,
  /(?:^|\s)(?:siktir|sikeyim|sikiyim|sikerim|sikicem|sikecem)(?:\s|$)/,
  /(?:^|\s)(?:yarrak|yarak)(?:\s|$)/,
  /(?:^|\s)(?:gotveren|got\s+veren)(?:\s|$)/,
  /(?:^|\s)(?:gerizekali|geri\s+zekali|aptal|salak)(?:\s|$)/,
  /(?:^|\s)(?:ibne|pezevenk)(?:\s|$)/
];

function moderateMessage(value) {
  const text = String(value || '').trim();
  if (!text) return { ok: false, code: 'MESSAGE_REQUIRED' };
  const normalized = normalizeText(text);
  if (blockedPatterns.some((pattern) => pattern.test(normalized))) {
    return { ok: false, code: 'MESSAGE_NOT_ALLOWED' };
  }
  return { ok: true, text };
}

module.exports = { moderateMessage };
