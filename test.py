import cx_Oracle


con = cx_Oracle.connect("meeamoon", "meeamoon", "localhost")

cur = con.cursor()

# QUERY = """
# BEGIN
# search_data('44 West');
# END;
# """
recommendations = []
result = cur.var(str)
cur.callproc('filter_data', ["Medium, star_5,Italian", result])
print(result.getvalue())
# cur.execute(QUERY)

# res = cur.fetchall()
# for row in res:
#     print(row)
