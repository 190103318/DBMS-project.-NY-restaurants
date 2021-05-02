from flask import Flask, render_template, request, redirect
import cx_Oracle
app = Flask(__name__)
con = cx_Oracle.connect("arna", "arna", "localhost")
cur = con.cursor()


@app.route('/')
def index_view():
    most_popular = []
    most_rated = []
    featured = []

    MOST_POPULAR = """
        SELECT NAME, STREET_ADDRESS, AVERAGE_REVIEW, ID, IMAGEE FROM
        (
        SELECT *
        FROM restaurants
        WHERE review_count IS NOT NULL AND extract_number(review_count) IS NOT NULL
        ORDER BY extract_number(review_count) DESC
        )
        WHERE ROWNUM <= 12
    """
    cur.execute(MOST_POPULAR)

    res = cur.fetchall()
    for row in res:
        most_popular.append(row)

    MOST_RATED = """
        SELECT NAME, STREET_ADDRESS, AVERAGE_REVIEW, ID, IMAGEE FROM (
            SELECT * FROM restaurants WHERE STAR_5 IS NOT NULL ORDER BY STAR_5 DESC
        ) WHERE ROWNUM <= 12
    """

    cur.execute(MOST_RATED)
    res = cur.fetchall()
    for row in res:
        most_rated.append(row)

    FEATURED = """
        SELECT NAME, STREET_ADDRESS, AVERAGE_REVIEW, REVIEW_COUNT, WEBSITE, IMAGEE 
        FROM   (
            SELECT *
            FROM
                (SELECT *
                FROM restaurants
                WHERE review_count IS NOT NULL AND extract_number(review_count) IS NOT NULL
                ORDER BY extract_number(review_count) DESC
                )
            WHERE ROWNUM <= 9
            ORDER BY DBMS_RANDOM.RANDOM)
        WHERE rownum < 2
    """

    cur.execute(FEATURED)
    res = cur.fetchall()
    for row in res:
        featured.append(row)

    cur.execute("select distinct restaurant_main_type from restaurants")
    cuisines = []
    res = cur.fetchall()
    for row in res:
        cuisines.append(row[0])

    return render_template("index.html", most_popular=most_popular, most_rated=most_rated, featured=featured, cuisines=cuisines)


@app.route('/view/<id>')
def view_res(id):
    ONE = """
        SELECT
            *
        FROM restaurants WHERE id = 
    """
    ONE += str(id)
    cur.execute(ONE)
    res = cur.fetchall()
    info = res[0]
    star_review_sum = sum(
        [res[0][13], res[0][14], res[0][15], res[0][16], res[0][17]])

    recommended = []

    result = cur.var(str)
    print(info[19])
    cur.callproc('recommend_data', [info[19], result])
    for line in result.getvalue().split(":::"):
        recommended.append(line.split("::"))
    recommended.pop()

    return render_template("view.html", info=info, star_review_sum=star_review_sum, recommended=recommended)


@app.route('/search')
def search_view():
    cur.execute("select distinct restaurant_main_type from restaurants")
    cuisines = []
    res = cur.fetchall()
    for row in res:
        cuisines.append(row[0])

    query = request.args.get("query")
    rating = request.args.get("rating")
    price = request.args.get("price")
    cuisine = request.args.get("cuisine")
    filtered = []
    if len(query) == 0:
        FILTER_QUERY = "%s, star_%s,%s" % (price, rating, cuisine)
        result = cur.var(str)
        cur.callproc('filter_data', [FILTER_QUERY, result])

        if result.getvalue() is not None:
            for rest in result.getvalue().split(":::"):
                filtered.append(rest.split("::"))
            filtered.pop()
            print(filtered)
    else:
        result = cur.var(str)
        cur.callproc("search_data", [query, result])
        if result.getvalue() is not None:
            for rest in result.getvalue().split(":::"):
                filtered.append(rest.split("::"))
            print(filtered)
            filtered.pop()

    return render_template("search.html", cuisines=cuisines, filtered=filtered)


@app.route('/admin')
def admin_view():
    NAMES = "SELECT id, name FROM restaurants"
    names = []
    cur.execute(NAMES)
    res = cur.fetchall()
    for row in res:
        names.append(row)
    return render_template("admin.html", names=names)


@app.route('/edit/<id>')
def edit_view(id):
    ONE = """
        SELECT
            name, street_address, google_map, review_count, phone,website,restaurant_type, average_review,food_review, service_review, ambience_review, value_review,price_range, star_1,star_2,star_3,star_4,star_5,description,restaurant_main_type,latitude,longitude,postal_code,id,price,imagee
        FROM restaurants WHERE id = 
    """
    ONE += str(id)
    cur.execute(ONE)
    res = cur.fetchall()
    info = res[0]
    length = len(info)

    colnames = 'name, street_address, google_map, review_count, phone,website,restaurant_type, average_review,food_review, service_review, ambience_review, value_review,price_range, star_1,star_2,star_3,star_4,star_5,description,restaurant_main_type,latitude,longitude,postal_code,id,price,imagee'.split(',')
    return render_template("edit.html", colnames=colnames, info=info, length=length)


@app.route("/add")
def add_view():
    COLNAMES = "Select COLUMN_NAME from user_tab_columns where table_name='RESTAURANTS'"
    colnames = []
    cur.execute(COLNAMES)
    res = cur.fetchall()
    for row in res:
        colnames.append(row[0])
    return render_template("add.html", colnames=colnames)


@app.route("/create")
def cerate_res():
    properties = ""
    for key, value in request.args.items():
        properties += "'" + value.replace("'", "''") + "',"
    CREATE_RES = "INSERT INTO restaurants VALUES(%s)" % properties
    last_char_index = CREATE_RES.rfind(",")
    CREATE_RES = CREATE_RES[:last_char_index] + \
        " " + CREATE_RES[last_char_index+1:]
    print(CREATE_RES)
    cur.execute(CREATE_RES)
    con.commit()
    return redirect("/admin")


@app.route("/save/<id>")
def save_data(id):
    properties = ""
    for key, value in request.args.items():
        properties += key + " = '" + value.replace("'", "''") + "',"
    UPDATE_RES = """UPDATE RESTAURANTS SET %s WHERE id = %s""" % (
        properties, id)

    last_char_index = UPDATE_RES.rfind(",")
    UPDATE_RES = UPDATE_RES[:last_char_index] + \
        " " + UPDATE_RES[last_char_index+1:]

    cur.execute(UPDATE_RES)
    con.commit()
    return redirect("/admin")


@app.route("/delete/<id>")
def delete_data(id):
    DELETE = "DELETE FROM restaurants WHERE id = %s" % id
    cur.execute(DELETE)
    con.commit()
    return redirect("/admin")


if __name__ == "__main__":
    app.run(debug=True)
