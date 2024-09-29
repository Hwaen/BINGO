from flask import Flask, request, jsonify
import requests
import urllib.parse
import uuid
import time
import json
import openai
import os
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# OpenAI API 키 설정
openai_api_key = os.getenv('OPENAI_API_KEY')
openai.api_key = openai_api_key

# Food Safety API 설정
apikey = '7fd3ff94eb8741edaaca'
base_url = 'http://openapi.foodsafetykorea.go.kr/api/'

# OCR API 설정
api_url = 'https://nz1c8myv6k.apigw.ntruss.com/custom/v1/34506/bb245718da05b49f6f7f4cb43bc5c0a15e1b7cd8a91e9d27565a2f49342d1a68/general'
secret_key = 'VkZ6WGdGQWlocUdvTktKdFZYaXVXVm9XdkJnV0tvR0Y='

@app.route('/process_recipe', methods=['POST'])
def process_receipt():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400

    file = request.files['file']

    request_json = {
        'images': [{'format': 'jpg', 'name': 'demo'}],
        'requestId': str(uuid.uuid4()),
        'version': 'V2',
        'timestamp': int(round(time.time() * 1000))
    }

    payload = {'message': json.dumps(request_json).encode('UTF-8')}
    files = [('file', file.read())]  # 이미지를 바이트로 읽음
    headers = {'X-OCR-SECRET': secret_key}

    response = requests.post(api_url, headers=headers, data=payload, files=files)

    if response.status_code == 200:
        result = response.json()
        items = [i['inferText'] for i in result['images'][0]['fields']] if 'fields' in result['images'][0] else []

        if items:
            gpt_response = openai.ChatCompletion.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are an assistant that identifies food ingredients from a product list."},
                    {"role": "user", "content": f"불필요한 말 제외하고 다음 목록에서 요리 가능한 재료와 요리 할 수 없는 재료 분류해줘. 출력할 땐 상표와 원산지를 제외하고 품명만 알려줘.: {', '.join(items)}"}
                ]
            )

            food_ingredients = gpt_response['choices'][0]['message']['content']
            return jsonify({'ingredients': food_ingredients})
        else:
            return jsonify({'error': 'No items found'}), 400
    else:
        return jsonify({'error': f'API request failed with status code {response.status_code}'}), 500

@app.route('/search_recipe', methods=['GET'])
def search_recipe():
    ingredient = request.args.get('ingredient', '')

    if not ingredient:
        return jsonify({"error": "No ingredient provided"}), 400

    # URL 인코딩 처리
    encoded_ingredient = urllib.parse.quote(ingredient)
    url = f"{base_url}{apikey}/COOKRCP01/json/1/5/RCP_NM={encoded_ingredient}"

    try:
        response = requests.get(url)
        response.raise_for_status()
        jsonData = response.json()

        # 응답 확인
        print(f"Response JSON: {jsonData}")  # 디버깅용

        result = jsonData.get("COOKRCP01", {})
        code = result.get("RESULT", {}).get("CODE", "")

        if code == "INFO-000":
            recipes = result.get("row", [])
            processed_recipes = []

            for recipe in recipes:
                recipe_data = {
                    'id': recipe.get('RCP_SEQ', 'N/A'),
                    'title': recipe.get('RCP_NM', 'N/A'),
                    'imageUrl': recipe.get('ATT_FILE_NO_MAIN', 'N/A'),
                    'imageUrl2': recipe.get('ATT_FILE_NO_MK', 'N/A'),
                    'description': recipe.get('INFO_ENG', 'N/A'),
                    'manualSteps': [],
                    'ingredients': recipe.get('RCP_PARTS_DTLS', 'N/A'),
                    'tip': recipe.get('RCP_NA_TIP', 'N/A'),
                    'category': recipe.get('RCP_PAT2', 'N/A'),
                }

                # 조리법 단계와 이미지 추가
                for i in range(1, 21):  # 20단계까지 처리
                    step_key = f'MANUAL{i:02}'
                    image_key = f'MANUAL_IMG{i:02}'
                    step = recipe.get(step_key, '').strip()
                    image = recipe.get(image_key, '').strip()
                    if step:
                        step_data = {'step': step}
                        if image:
                            step_data['image'] = image
                        recipe_data['manualSteps'].append(step_data)

                processed_recipes.append(recipe_data)

            return jsonify(processed_recipes)
        else:
            return jsonify({"error": "데이터를 찾을 수 없습니다."}), 404
    except requests.RequestException as e:
        return jsonify({"error": "API 요청 오류", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
