#include <eleven.h>
#include <Python.h>

static PyObject * answer(PyObject *self, PyObject *args)
{
    int result = 31 + eleven();
    return PyLong_FromLong(result);
}

/* Module initialization */
static PyMethodDef module_methods[] = {
    {"answer", (PyCFunction)answer, METH_NOARGS, "The answer."},
    {NULL}  /* Sentinel */
};

PyMODINIT_FUNC PyInit_forty_two(void)
{
    static struct PyModuleDef moduledef = {
        PyModuleDef_HEAD_INIT, "forty_two", "The answer module", -1, module_methods,
    };
    return PyModule_Create(&moduledef);
}
