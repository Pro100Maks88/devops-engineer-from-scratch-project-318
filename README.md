# Доска объявлений (Observability)

[![hexlet-check](https://github.com/Pro100Maks88/devops-engineer-from-scratch-project-318/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Pro100Maks88/devops-engineer-from-scratch-project-318/actions)

Автоматизация раскатывания контейнеризированного приложения на сервер в облаке.

Учебный проект Хекслета: https://ru.hexlet.io/programs/devops-engineer-from-scratch
Как это должно работать: https://asciinema.org/a/v4evn7XjCdou7Yh71IG0ljb0W

## Стек

- **Java / Spring Boot** — приложение «доска объявлений» (REST API)
- **Docker** — контейнеризация приложения
- **Ansible** — автоматизация настройки и деплоя
- **Make** — интерфейс для запуска задач
- **Yandex Cloud** — инфраструктура (ВМ, Managed PostgreSQL, Object Storage)

## Инфраструктура

| Компонент | Адрес / Данные |
| :--- | :--- |
| Сервер (ВМ Yandex Cloud) | `130.193.58.173` |
| Приложение (API, Swagger UI) | `http://130.193.58.173:8080` |
| Health-check | `http://130.193.58.173:9090/actuator/health` |
| PostgreSQL | `rc1d-fnumjpmf6ujptcks.mdb.yandexcloud.net:6432`, база `bulletin` |
| Object Storage | бакет `bulletin-storage` |

## Где лежат плейбуки

Плейбуки Ansible расположены в директории `ansible/`:

- `ansible/deploy.yml` — основной плейбук для подготовки сервера и деплоя приложения;
- `ansible/inventory.ini` — инвентарь (список хостов) для Ansible;
- `ansible/.env` — переменные окружения (секреты), не попадают в репозиторий (см. `.gitignore`).

## Установка

```bash
git clone https://github.com/Pro100Maks88/devops-engineer-from-scratch-project-318.git
cd devops-engineer-from-scratch-project-318
```

Перед запуском необходимо подготовить файл с секретами:

```bash
cp ansible/.env.example ansible/.env
```
(Если файла .env.example нет, создайте ansible/.env вручную и пропишите в нём переменные согласно документации проекта).

Заполните ansible/.env данными вашего окружения (IP, пользователь, пароли).

## Команды запуска
Все операции выполняются через Makefile в корне проекта:


## О Хекслете

[Хекслет](https://ru.hexlet.io/) — школа программирования: авторские программы обучения с практикой, поддержкой наставников и реальными проектами, которые остаются в резюме. Этот репозиторий — один из таких проектов.