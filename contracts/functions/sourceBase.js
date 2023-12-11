const words = args[0];
const tokenId = args[1];
if (!secrets.apiKey) {
  throw Error('Need betblock key!');
}
const apiRequest = Functions.makeHttpRequest({
  url: "https://api.betblock.fi/generateImage",
  headers: {
    "x-api-key": secrets.apiKey,
    'Content-Type': 'application/json'
  },
  params: {
    words: words,
    tokenId: tokenId
  },
});
const apiResponse = await apiRequest;
if (apiResponse.error) {
  throw new Error("Response Error");
}
const val = apiResponse['data']
console.log(val['image'])
return Functions.encodeString(val['image'])