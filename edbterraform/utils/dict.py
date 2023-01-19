"""
Change all keys within a dictionary
with a replace_pairs dictionary containing: key to find => value to change to

ex.
change_keys(obj={"az": 1234}, replace_pairs={"az":"zone", "azs":"zones"})
=> {"zone":1234}
"""
def change_keys(obj: any, replace_pairs: dict):

    if isinstance(obj, dict):
        new = type(obj)()
        for key, value in obj.items():
            if key in replace_pairs:
                new[replace_pairs[key]] = change_keys(value, replace_pairs)
            else:
                new[key] = change_keys(value, replace_pairs)
    elif isinstance(obj, (list, set, tuple)):
        new = type(obj)(change_keys(item, replace_pairs) for item in obj)
    else: # fallthrough for int, float, str or other
        return obj

    return new
