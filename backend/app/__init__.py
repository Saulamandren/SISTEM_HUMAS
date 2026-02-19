import os

from flask import Flask
from flask_cors import CORS
from flask_mysqldb import MySQL

mysql = MySQL()

from app.config import config_by_name
from app.routes.auth_routes import auth_bp
from app.routes.category import category_bp
from app.routes.content import content_bp
from app.routes.cooperation import cooperation_bp
from app.routes.user_routes import user_bp


def create_app():
    app = Flask(__name__)

    env = os.getenv('FLASK_ENV', 'default')
    app.config.from_object(config_by_name.get(env, config_by_name['default']))

    CORS(app)
    mysql.init_app(app)

    app.register_blueprint(auth_bp)
    app.register_blueprint(user_bp)
    app.register_blueprint(category_bp, url_prefix='/api/categories')
    app.register_blueprint(content_bp, url_prefix='/api/contents')
    app.register_blueprint(cooperation_bp, url_prefix='/api/cooperations')

    @app.route('/health')
    def health():
        return {'status': 'success', 'message': 'Backend ready!', 'data': None}, 200

    return app
